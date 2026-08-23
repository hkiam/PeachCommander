// SPDX-License-Identifier: Apache-2.0
// S3Transfer.swift — object bytes, off the heap and with a way to stop.
//
// `URLSession`'s download task is used rather than a data task for one reason: an S3 object is
// routinely larger than memory, and the host already hands us a destination path so that the bytes
// never have to be held. The delegate is also the only place progress exists — and progress is the
// only place an abort can be answered, because the PFX ABI's cancellation channel *is* the progress
// callback returning PC_ABORT.

import Foundation

/// What a transfer did. `aborted` is separate from a status, because a cancelled transfer has none.
struct S3TransferOutcome {
    let status: Int
    let headers: [String: String]
    /// The response body when the status was not a success — S3 writes an `<Error>` document, and
    /// throwing it away is how "the download failed" replaces "this object is archived".
    let errorBody: Data?
    let aborted: Bool
}

final class S3TransferDelegate: NSObject, URLSessionDownloadDelegate, URLSessionDataDelegate {
    /// State for the one transfer in flight. Single-slot rather than keyed by task: the host
    /// serialises calls on a connection, so a second concurrent transfer on one connection is not
    /// something the ABI permits — and pretending to support it would hide a real bug if it happened.
    private final class Job {
        let name: String
        let progress: ((String, Int) -> Bool)?
        let finish: (URL) throws -> Void
        let done = DispatchSemaphore(value: 0)
        var status = 0
        var headers: [String: String] = [:]
        var errorBody: Data?
        var aborted = false
        var lastReported = -1
        init(name: String, progress: ((String, Int) -> Bool)?, finish: @escaping (URL) throws -> Void) {
            self.name = name
            self.progress = progress
            self.finish = finish
        }
    }

    private let lock = NSLock()
    private var job: Job?

    private func current() -> Job? {
        lock.lock(); defer { lock.unlock() }
        return job
    }

    /// Run one upload-from-file to completion and return what happened.
    ///
    /// `uploadTask(with:fromFile:)` rather than a body in memory: the source is a local file the host
    /// has already written, and holding a multi-gigabyte object in `Data` to send it would undo the
    /// whole reason the ABI passes paths around.
    func upload(session: URLSession, request: URLRequest, file: URL, name: String,
                progress: ((String, Int) -> Bool)?) -> S3TransferOutcome {
        let job = Job(name: name, progress: progress, finish: { _ in })
        lock.lock(); self.job = job; lock.unlock()
        defer { lock.lock(); self.job = nil; lock.unlock() }

        let task = session.uploadTask(with: request, fromFile: file)
        task.resume()
        job.done.wait()
        return S3TransferOutcome(status: job.status, headers: job.headers,
                                 errorBody: job.errorBody, aborted: job.aborted)
    }

    /// Run one download to completion and return what happened.
    ///
    /// `finish` is called with the temporary file while it still exists — `URLSession` deletes it as
    /// soon as the delegate method returns, so moving it later means moving nothing.
    func run(session: URLSession, request: URLRequest, name: String,
             progress: ((String, Int) -> Bool)?,
             finish: @escaping (URL) throws -> Void) -> S3TransferOutcome {
        let job = Job(name: name, progress: progress, finish: finish)
        lock.lock(); self.job = job; lock.unlock()
        defer { lock.lock(); self.job = nil; lock.unlock() }

        let task = session.downloadTask(with: request)
        task.resume()
        job.done.wait()
        return S3TransferOutcome(status: job.status, headers: job.headers,
                                 errorBody: job.errorBody, aborted: job.aborted)
    }

    // MARK: - URLSessionTaskDelegate / URLSessionDataDelegate (uploads)

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didSendBodyData bytesSent: Int64, totalBytesSent: Int64,
                    totalBytesExpectedToSend: Int64) {
        guard let job = current(), let report = job.progress else { return }
        let pct = totalBytesExpectedToSend > 0
            ? min(100, Int(totalBytesSent * 100 / totalBytesExpectedToSend)) : 0
        guard pct != job.lastReported else { return }
        job.lastReported = pct
        if !report(job.name, pct) {
            job.aborted = true
            task.cancel()
        }
    }

    /// An upload's *response* body, which for a failure is the `<Error>` document.
    ///
    /// Collected here because an upload task has no download location to read it from, and without it
    /// a refused PUT can only be reported as its status code — so "this bucket does not allow
    /// unencrypted uploads" arrives as a bare 403.
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let job = current() else { return }
        job.errorBody = (job.errorBody ?? Data()) + data
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let job = current(), let http = response as? HTTPURLResponse {
            job.status = http.statusCode
            for (k, v) in http.allHeaderFields {
                if let key = k as? String, let value = v as? String { job.headers[key] = value }
            }
        }
        completionHandler(.allow)
    }

    // MARK: - URLSessionDownloadDelegate

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard let job = current(), let report = job.progress else { return }
        // A server that sends no Content-Length reports -1 here, and there is no percentage to give.
        // Reporting 0 forever would look like a stall; reporting nothing at all still lets the abort
        // question be asked, which is the half that matters.
        let pct: Int
        if totalBytesExpectedToWrite > 0 {
            pct = min(100, Int(totalBytesWritten * 100 / totalBytesExpectedToWrite))
        } else {
            pct = 0
        }
        // Only on a change, so a large object does not ask the host the same question ten thousand
        // times — the callback crosses into the app and takes a lock on the way.
        guard pct != job.lastReported else { return }
        job.lastReported = pct
        if !report(job.name, pct) {
            job.aborted = true
            downloadTask.cancel()
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        guard let job = current() else { return }
        if let http = downloadTask.response as? HTTPURLResponse {
            job.status = http.statusCode
            for (k, v) in http.allHeaderFields {
                if let key = k as? String, let value = v as? String { job.headers[key] = value }
            }
        }
        guard (200...299).contains(job.status) else {
            // The error document was downloaded like any other body. Read it here, while the file is
            // still there, so the caller can say which failure this was.
            job.errorBody = try? Data(contentsOf: location)
            return
        }
        do { try job.finish(location) }
        catch {
            // The bytes arrived and could not be put where they belong — a full disk, a read-only
            // destination. Reported as a local write failure rather than as an HTTP result, because
            // the server did nothing wrong.
            job.status = -1
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let job = current() else { return }
        if let error {
            if (error as NSError).code == NSURLErrorCancelled { job.aborted = true }
            // `status` stays 0 for a transport failure, which is what the caller maps onto
            // "the connection is gone" — the same meaning it has for a metadata request.
            if job.status == 0, let http = task.response as? HTTPURLResponse {
                job.status = http.statusCode
            }
        }
        job.done.signal()
    }
}
