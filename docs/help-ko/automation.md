---
title: 자동화(AppleScript 및 단축어)
slug: automation
section: 고급 도구
order: 98
related: [start-menu, settings]
---

Peach Commander는 스크립트로 제어할 수 있으므로 AppleScript와 단축어 앱에서 구동할 수 있습니다. 몇 가지 핵심 동사를 통해 스크립트가 패널을 탐색하고, 마스크로 파일을 선택하고, 현재 선택 항목을 복사하거나 이동하고, id로 임의의 Peach Commander 명령을 실행할 수 있습니다. 메뉴가 사용하는 것과 정확히 같은 동작을 재사용하므로, 스크립트로 실행하는 단계도 수동 단계처럼 동작합니다. 다운로드 정리, 빌드 출력물 준비, 파일 단계를 더 큰 단축어에 연결하는 등 반복적인 잡무에 편리합니다.

## 사전 보기

1. **스크립트 편집기**(`/Applications/Utilities`에 있음)를 엽니다.
2. **윈도우 ▸ 라이브러리**를 선택한 다음 **Peach Commander**를 두 번 클릭합니다(목록에 없으면 **+**로 추가합니다).
3. 사전이 열리며 아래의 명령과 속성이 나열됩니다.

스크립트가 Peach Commander를 처음 제어할 때 macOS는 이를 허용할지 묻습니다(**시스템 설정 ▸ 개인정보 보호 및 보안 ▸ 자동화**). 한 번 승인하면 이후 스크립트는 묻지 않고 실행됩니다.

## 읽을 수 있는 것

| 속성 | 의미 |
| --- | --- |
| `active folder` | 활성 패널 폴더의 POSIX 경로. |
| `inactive folder` | 다른 패널 폴더의 POSIX 경로. |
| `selection paths` | 활성 패널에서 선택된 항목(또는 커서 아래의 항목). |

## 동사

| 명령 | 하는 일 |
| --- | --- |
| `go to "<path>" [in left\|right]` | 패널에서 폴더를 엽니다(기본값: 활성 패널). |
| `select "<mask>"` | 와일드카드 마스크로 활성 패널의 항목을 선택합니다(예: `*.pdf`). |
| `copy items to "<folder>"` | 활성 패널의 선택 항목을 폴더로 복사합니다. |
| `move items to "<folder>"` | 활성 패널의 선택 항목을 폴더로 이동합니다. |
| `run command "<id>"` | id로 임의의 명령을 실행합니다(예: `cm_PackFiles`). |

복사와 이동은 F5/F6과 같은 백그라운드 전송 대기열을 사용하므로, 진행 상황과 덮어쓰기 프롬프트가 수동 작업과 정확히 동일하게 나타납니다.

## 예시

```applescript
tell application "Peach Commander"
    go to "~/Downloads" in left
    select "*.pdf"
    copy items to "~/Documents/PDFs"
    return selection paths
end tell
```

## 단축어에서 사용하기

**단축어** 앱에서 **AppleScript 실행** 동작을 추가하고 위와 같은 스크립트를 붙여 넣습니다. 그러면 Peach Commander 단계를 더 큰 단축어에 접어 넣을 수 있습니다. 예를 들어 폴더 변경이나 단축키로 트리거할 수 있습니다.

## 참고

- `run command`에 전달하는 명령 id는 명령 브라우저에 표시되는 것과 같은 `cm_*` id입니다([시작 메뉴 및 사용자 지정 명령](start-menu.md) 참조).
- 스크립팅은 항상 **활성** 패널에 작용합니다. 특정 쪽이 필요하면 먼저 `go to … in left` / `in right`를 사용하십시오.
- Peach Commander는 단일 창 앱이므로 스크립트는 해당 창의 두 패널을 대상으로 합니다.
