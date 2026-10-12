"""Frozen cycle oracles. Inputs applied before edge; outputs sampled after edge."""
import random

PORTS = {
    'fifo': ({'rst':1,'push':1,'pop':1,'din':8}, {'dout':8,'empty':1,'full':1,'count':3}),
    'uart': ({'rst':1,'send':1,'data':8}, {'tx':1,'busy':1}),
    'axi_lite': ({'rst':1,'awvalid':1,'awaddr':4,'wvalid':1,'wdata':32,'wstrb':4,'bready':1,'arvalid':1,'araddr':4,'rready':1}, {'awready':1,'wready':1,'bvalid':1,'bresp':2,'arready':1,'rvalid':1,'rdata':32,'rresp':2}),
    'cordic': ({'rst':1,'valid_in':1,'x_in':16,'y_in':16,'z_in':16}, {'valid_out':1,'x_out':16,'y_out':16,'z_out':16}),
    'cache': ({'rst':1,'req':1,'write':1,'addr':8,'wdata':16}, {'valid':1,'hit':1,'rdata':16}),
}


def signed(v):
    v &= 65535
    return v - 65536 if v & 32768 else v


class Oracle:
    def __init__(self, design):
        self.design = design
        self.reset()

    def reset(self):
        self.q = []
        self.bits = []
        self.tick = 0
        self.regs = [0]*4
        self.aw = None
        self.w = None
        self.bvalid = self.rvalid = self.rdata = 0
        self.lines = [None]*4
        self.memory = {}
        self.result = [0,0,0]

    def step(self, a):
        if a['rst']:
            self.reset()
        elif self.design == 'fifo':
            old = len(self.q)
            if a['pop'] and old:
                self.q.pop(0)
            if a['push'] and old < 4:
                self.q.append(a['din'])
        elif self.design == 'uart':
            if self.bits:
                self.tick += 1
                if self.tick == 4:
                    self.bits.pop(0)
                    self.tick = 0
            elif a['send']:
                self.bits = [0] + [(a['data'] >> i) & 1 for i in range(8)] + [1]
                self.tick = 0
        elif self.design == 'axi_lite':
            # Commit uses only previously buffered AW and W, not new captures.
            old_b = self.bvalid
            if self.bvalid and a['bready']:
                self.bvalid = 0
            if self.aw is not None and self.w is not None and not old_b:
                data, strobe = self.w
                mask = sum(255 << (8*i) for i in range(4) if strobe >> i & 1)
                self.regs[self.aw] = (self.regs[self.aw] & ~mask) | (data & mask)
                self.aw = self.w = None
                self.bvalid = 1
            else:
                if self.aw is None and not old_b and a['awvalid']:
                    self.aw = a['awaddr'] >> 2
                if self.w is None and not old_b and a['wvalid']:
                    self.w = (a['wdata'], a['wstrb'])
            # Reads see pre-edge registers, including when a write commits.
            # Capture read value before write is handled in step wrapper below.
            if not self.rvalid and a['arvalid']:
                self.rvalid = 1
                self.rdata = self.old_regs[a['araddr'] >> 2]
            elif self.rvalid and a['rready']:
                self.rvalid = 0
        elif self.design == 'cordic':
            if a['valid_in']:
                x,y,z = [signed(a[k]) for k in ('x_in','y_in','z_in')]
                for i, angle in enumerate((8192,4836,2555,1297)):
                    direction = 1 if z >= 0 else -1
                    x,y,z = signed(x-direction*(y >> i)), signed(y+direction*(x >> i)), signed(z-direction*angle)
                self.result = [v & 65535 for v in (x,y,z)]
        elif self.design == 'cache':
            if a['req']:
                addr = a['addr']
                index = addr & 3
                self.cache_hit = int(self.lines[index] is not None and self.lines[index][0] == addr)
                value = a['wdata'] if a['write'] else self.memory.get(addr, addr*257)
                self.cache_data = value
                self.lines[index] = (addr, value)
                if a['write']:
                    self.memory[addr] = value
        d = self.design
        if d == 'fifo':
            return dict(dout=self.q[0] if self.q else 0, empty=int(not self.q), full=int(len(self.q)==4), count=len(self.q))
        if d == 'uart':
            return dict(tx=self.bits[0] if self.bits else 1, busy=int(bool(self.bits)))
        if d == 'axi_lite':
            return dict(awready=int(self.aw is None and not self.bvalid), wready=int(self.w is None and not self.bvalid), bvalid=self.bvalid,bresp=0,arready=int(not self.rvalid),rvalid=self.rvalid,rdata=self.rdata,rresp=0)
        if d == 'cordic':
            return dict(valid_out=int(not a['rst'] and a['valid_in']), **dict(zip(('x_out','y_out','z_out'),self.result)))
        return dict(valid=int(not a['rst'] and a['req']),hit=0 if a['rst'] else getattr(self,'cache_hit',0),rdata=0 if a['rst'] else getattr(self,'cache_data',0))

    def cycle(self, a):
        self.old_regs = self.regs.copy()
        if a['rst']:
            self.cache_hit = self.cache_data = 0
        return self.step(a)


def vectors(design, seed, cycles=300):
    """Directed boundary prefix followed by seeded stress and mid-stream reset."""
    rng = random.Random(seed)
    ins, _ = PORTS[design]
    rows = []
    def add(**kw):
        row = dict.fromkeys(ins,0)
        row.update(kw)
        rows.append(row)
    add(rst=1)
    add()
    if design == 'fifo':
        for i in range(6): add(push=1,din=i+11)
        add(push=1,pop=1,din=99)
        for _ in range(6): add(pop=1)
        add(push=1,pop=1,din=255)
    elif design == 'uart':
        for data in (0,255,85,170):
            add(send=1,data=data)
            for i in range(41): add(send=int(i==9),data=123)
    elif design == 'axi_lite':
        for index in range(4):
            add(awvalid=1,awaddr=index*4)
            add(wvalid=1,wdata=0x12345678+index,wstrb=15)
            add()
            add()
            add(bready=1)
            add(arvalid=1,araddr=index*4)
            add()
            add(rready=1)
        add(awvalid=1,awaddr=0,wvalid=1,wdata=0xffffffff,wstrb=5)
        add(); add(bready=1); add(bready=1)
        add(arvalid=1); add(rready=1)
    elif design == 'cordic':
        for z in (-8192,-1,0,1,8192):
            for x,y in ((1000,0),(0,1000),(-1000,-1000)):
                add(valid_in=1,x_in=x&65535,y_in=y&65535,z_in=z&65535)
            add()
        for x,y,z in ((32767,32767,0),(-32768,-32768,-32768),(32767,-32768,32767)):
            add(valid_in=1,x_in=x&65535,y_in=y&65535,z_in=z&65535)
    else:
        for addr in (0,0,4,0,255,255): add(req=1,addr=addr)
        add(req=1,write=1,addr=0,wdata=1234)
        add(req=1,addr=4); add(req=1,addr=0)
    for n in range(cycles):
        row = {k:rng.getrandbits(w) for k,w in ins.items()}
        row['rst'] = int(n==cycles//2)
        if design == 'cordic':
            row.update(x_in=rng.randint(-1000,1000)&65535,y_in=rng.randint(-1000,1000)&65535,z_in=rng.randint(-8192,8192)&65535)
        rows.append(row)
    model = Oracle(design)
    return [(a,model.cycle(a)) for a in rows]
