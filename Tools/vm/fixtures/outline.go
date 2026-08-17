// SPDX-License-Identifier: Apache-2.0
// A fixture for the Go symbol outline (F-405). The receiver form is the point: `func (m *Machine) Greet`
// must be listed as Greet and not as m, which is what a missing receiver rule produces.

package main

import "fmt"

type Machine struct {
	ID int
}

type Greeter interface {
	Greet(name string) string
}

func (m *Machine) Greet(name string) string {
	return fmt.Sprintf("hi %s from %d", name, m.ID)
}

func main() {
	m := &Machine{ID: 1}
	fmt.Println(m.Greet("world"))
}
