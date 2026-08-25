package client

import "sync/atomic"

type Dispatcher interface {
	Dispatch(opcode uint32, fd int, data []byte)
}

type Proxy interface {
	Context() *Context
	SetContext(ctx *Context)
	ID() uint32
	SetID(id uint32)
	IsZombie() bool
	MarkZombie()
}

type WaylandDisplay interface {
	Context() *Context
	GetRegistry() (*Registry, error)
	Roundtrip() error
	Destroy() error
}

var _ WaylandDisplay = (*Display)(nil)

type BaseProxy struct {
	ctx    *Context
	id     uint32
	zombie atomic.Bool
}

func (p *BaseProxy) ID() uint32 {
	return p.id
}

func (p *BaseProxy) SetID(id uint32) {
	p.id = id
}

func (p *BaseProxy) Context() *Context {
	return p.ctx
}

func (p *BaseProxy) SetContext(ctx *Context) {
	p.ctx = ctx
}

func (p *BaseProxy) IsZombie() bool {
	return p.zombie.Load()
}

func (p *BaseProxy) MarkZombie() {
	p.zombie.Store(true)
}
