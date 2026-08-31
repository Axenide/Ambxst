// Portions Copyright (c) 2025 Avenge Media LLC
// Licensed under the MIT License. Derived from DankMaterialShell.

package shm

import "golang.org/x/sys/unix"

func CreateAnonFd(name string) (int, error) {
	return unix.MemfdCreate(name, 0)
}
