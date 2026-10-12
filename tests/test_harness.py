import json
from pathlib import Path
import shutil
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch

from bench.models import Oracle, vectors
from bench.runner import ROOT, command, evaluate, inside, tool

MUTATIONS = {
    'fifo': ('assign full=count==4;', 'assign full=count==3;'),
    'uart': ("frame<={1'b1,data,1'b0}", "frame<={1'b1,data,1'b1}"),
    'axi_lite': ('if(ws[i])', 'if(1)'),
    'cordic': ('if(z>=0)', 'if(z>0)'),
    'cache': ('tags[addr[1:0]]==addr', "tags[addr[1:0]][1:0]==addr[1:0]"),
}


def mutant(design, destination):
    (destination / 'rtl').mkdir(parents=True)
    original = (ROOT / 'fixtures' / design / 'rtl' / (design+'.v')).read_text()
    before, after = MUTATIONS[design]
    assert before in original, f'Mutation target absent: {design}'
    (destination / 'rtl' / (design+'.v')).write_text(original.replace(before, after))


class HarnessTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='.test-', dir=ROOT)
        self.base = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def test_fifo_boundary_contract(self):
        oracle = Oracle('fifo')
        for n in range(4):
            r = oracle.cycle(dict(rst=0,push=1,pop=0,din=n))
        self.assertEqual(r['count'], 4)
        r = oracle.cycle(dict(rst=0,push=1,pop=1,din=99))
        self.assertEqual((r['count'],r['dout']), (3,1))
        for _ in range(3):
            oracle.cycle(dict(rst=0,push=0,pop=1,din=0))
        r = oracle.cycle(dict(rst=0,push=1,pop=1,din=99))
        self.assertEqual((r['count'],r['dout']), (1,99))

    def test_uart_frame_duration(self):
        oracle = Oracle('uart')
        outputs = [oracle.cycle(dict(rst=0,send=int(n==0),data=0x55)) for n in range(41)]
        self.assertEqual([r['tx'] for r in outputs[:40]], [b for b in [0,1,0,1,0,1,0,1,0,1] for _ in range(4)])
        self.assertEqual(outputs[40], dict(tx=1,busy=0))

    def test_seed_is_repeatable(self):
        self.assertEqual(vectors('fifo',1), vectors('fifo',1))
        self.assertNotEqual(vectors('fifo',1), vectors('fifo',2))

    def test_timeout_and_missing(self):
        r = command([sys.executable,'-c','while True: pass'], self.base, 'hang', .05)
        self.assertEqual(r['status'], 'timeout')
        self.assertEqual(command(None,self.base,'absent',1)['status'],'missing')

    def test_absent_tools_cannot_pass(self):
        with patch('bench.runner.tool', return_value=None):
            r = evaluate('fifo',ROOT/'fixtures/fifo',self.base/'missing')
        self.assertFalse(r['overall_pass'])
        self.assertEqual(r['equivalence'],'missing')
        self.assertEqual(r['synthesis'],'missing')

    def test_path_constraint(self):
        with self.assertRaises(ValueError):
            inside(ROOT.parent/'elsewhere')

    @unittest.skipUnless(tool('iverilog') and tool('vvp') and tool('yosys'), 'Requires EDA tools')
    def test_fixtures_and_each_mutation(self):
        for design in MUTATIONS:
            with self.subTest(design=design):
                good = evaluate(design, ROOT/'fixtures'/design, self.base/(design+'-good'))
                self.assertTrue(good['overall_pass'])
                candidate = self.base/(design+'-candidate')
                mutant(design,candidate)
                bad = evaluate(design,candidate,self.base/(design+'-bad'))
                self.assertEqual(bad['equivalence'], 'fail')
                self.assertFalse(bad['overall_pass'])
                self.assertEqual(bad['synthesis'], 'pass')
                with tarfile.open(self.base/(design+'-bad.tar.gz')) as tar:
                    names = tar.getnames()
                    self.assertIn(design+'-bad/trace.vcd',names)
                    self.assertIn(design+'-bad/oracle.py',names)

    def test_invalid_metadata(self):
        candidate = self.base/'candidate'
        shutil.copytree(ROOT/'fixtures/fifo',candidate)
        (candidate/'metadata.json').write_text(json.dumps(dict(tokens=-1)))
        with self.assertRaises(ValueError):
            evaluate('fifo',candidate,self.base/'invalid')


if __name__ == '__main__':
    unittest.main()
