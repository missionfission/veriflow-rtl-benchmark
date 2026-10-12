"""Independent, dependency-free bounded cycle checking and archived EDA evidence."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import time

from .models import PORTS, vectors

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def tool(name):
    found = shutil.which(name)
    if found:
        return [found]
    local = ROOT / '.tools/root/usr/bin' / name
    if local.exists():
        cmd = [str(local)]
        if name == 'iverilog':
            cmd += ['-B', str(ROOT / '.tools/root/usr/lib/x86_64-linux-gnu/ivl')]
        return cmd
    return None


def command(cmd, work, label, timeout):
    start = time.monotonic()
    record = dict(command=cmd, returncode=None, seconds=0, status='missing')
    output = 'Tool unavailable\n'
    if cmd:
        try:
            proc = subprocess.run(cmd, cwd=work, stdout=subprocess.PIPE,
                                  stderr=subprocess.STDOUT, timeout=timeout)
            output = proc.stdout.decode(errors='replace')
            record.update(returncode=proc.returncode, status='pass' if proc.returncode == 0 else 'fail')
        except subprocess.TimeoutExpired as exc:
            output = (exc.stdout or b'').decode(errors='replace') + '\nTIMEOUT\n'
            record['status'] = 'timeout'
        except OSError as exc:
            output = str(exc) + '\n'
            record['status'] = 'error'
    record['seconds'] = round(time.monotonic() - start, 4)
    (work / (label + '.log')).write_text(output)
    return record


def testbench(design, rows):
    inputs, outputs = PORTS[design]
    def declaration(kind, name, width):
        return f'{kind} ' + (f'[{width-1}:0] ' if width > 1 else '') + name + ';'
    lines = ['`timescale 1ns/1ps', 'module tb;', 'reg clk=0;']
    lines += [declaration('reg', k, w) for k, w in inputs.items()]
    lines += [declaration('wire', k, w) for k, w in outputs.items()]
    names = ['clk'] + list(inputs) + list(outputs)
    lines += [f'{design} dut(' + ','.join(f'.{k}({k})' for k in names) + ');',
              'initial begin', '$dumpfile("trace.vcd"); $dumpvars(0,tb);']
    for cycle, (a, expected) in enumerate(rows):
        lines += [f'{k} = {inputs[k]}\'h{v:x};' for k, v in a.items()]
        lines += ['#5; clk=1; #1;']
        for k, v in expected.items():
            lines.append(f'if ({k} !== {outputs[k]}\'h{v:x}) begin '
                         f'$display("MISMATCH cycle={cycle} port={k} expected={v:x} actual=%h", {k}); $fatal(1); end')
        lines += ['#4; clk=0;']
    lines += [f'$display("BENCH_PASS cycles={len(rows)}");', '$finish;', 'end', 'endmodule']
    return '\n'.join(lines) + '\n'


def evaluate(design, candidate, work, seed=0, timeout=60, kind='imported'):
    work.mkdir(parents=True, exist_ok=False)
    started = time.monotonic()
    rtl = work / 'rtl'
    rtl.mkdir()
    sources = sorted((candidate / 'rtl').glob('*.v')) + sorted((candidate / 'rtl').glob('*.sv'))
    hashes = {}
    for src in sources:
        shutil.copyfile(src, rtl / src.name)
        hashes['rtl/' + src.name] = digest(src)
    shutil.copyfile(ROOT / 'specs' / (design + '.md'), work / 'requirement.md')
    shutil.copyfile(ROOT / 'bench/models.py', work / 'oracle.py')
    shutil.copyfile(ROOT / 'bench/runner.py', work / 'runner.py')
    rows = vectors(design, seed)
    (work / 'vectors.json').write_text(json.dumps(rows))
    (work / 'tb.v').write_text(testbench(design, rows))
    metadata = {}
    if (candidate / 'metadata.json').exists():
        metadata = json.loads((candidate / 'metadata.json').read_text())
    # Preserve only explicitly documented non-secret provenance, never session logs.
    allowed = ('run_id', 'model', 'upstream_revision', 'retries', 'tokens', 'generation_seconds', 'fresh_generation')
    metadata = {k: metadata[k] for k in allowed if k in metadata}
    for key in ('retries', 'tokens', 'generation_seconds'):
        value = metadata.get(key)
        if value is not None and (isinstance(value, bool) or not isinstance(value, (int, float)) or value < 0):
            raise ValueError(f'{key} must be a nonnegative number or null')
    (work / 'metadata.json').write_text(json.dumps(metadata, indent=2))
    srcnames = ['rtl/' + p.name for p in sources]
    iv, vv, ys = tool('iverilog'), tool('vvp'), tool('yosys')
    lint = command(iv + ['-g2012', '-Wall', '-s', design, '-t', 'null'] + srcnames if iv and sources else None,
                   work, 'lint', timeout)
    if lint['status'] == 'pass' and 'warning:' in (work / 'lint.log').read_text().lower():
        lint['status'] = 'warn'
    compile_result = command(iv + ['-g2012', '-s', 'tb', '-o', 'sim.out', 'tb.v'] + srcnames if iv and sources else None,
                             work, 'compile', timeout)
    sim = command(vv + ['sim.out'] if vv and compile_result['status'] == 'pass' else None,
                  work, 'simulation', timeout)
    if sim['status'] == 'pass' and f'BENCH_PASS cycles={len(rows)}' not in (work / 'simulation.log').read_text():
        sim['status'] = 'fail'
    # Generated source names are quoted in Yosys's command language.
    def yquote(s):
        return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'
    script = 'read_verilog -sv ' + ' '.join(yquote(n) for n in srcnames)
    script += f'; hierarchy -check -top {design}; synth -top {design} -noabc; check -assert; stat; write_json netlist.json'
    synth = command(ys + ['-Q', '-T', '-p', script] if ys and sources else None, work, 'synthesis', timeout)
    result = dict(design=design, kind=kind, seed=seed, cycles=len(rows), rtl_sha256=hashes,
                  spec_sha256=digest(work / 'requirement.md'), oracle_sha256=digest(ROOT / 'bench/models.py'),
                  equivalence=sim['status'], lint=lint['status'], synthesis=synth['status'],
                  overall_pass=all(r['status'] == 'pass' for r in (sim, lint, synth)),
                  retries=metadata.get('retries'), tokens=metadata.get('tokens'),
                  generation_seconds=metadata.get('generation_seconds'),
                  evaluation_seconds=round(time.monotonic()-started, 4), metadata=metadata,
                  stages=dict(lint=lint, compile=compile_result, simulation=sim, synthesis=synth))
    (work / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    # Executable simulation image is reproducible from RTL + TB; omit it from archive.
    (work / 'sim.out').unlink(missing_ok=True)
    archive = work.with_suffix('.tar.gz')
    with tarfile.open(archive, 'w:gz') as tar:
        tar.add(work, arcname=work.name)
    result['archive'] = archive.name
    result['archive_sha256'] = digest(archive)
    return result


def reports(results, out, kind):
    (out / 'results.json').write_text(json.dumps(dict(schema_version=1, kind=kind, runs=results), indent=2) + '\n')
    fields = ['design', 'seed', 'equivalence', 'lint', 'synthesis', 'overall_pass', 'retries', 'tokens',
              'generation_seconds', 'evaluation_seconds', 'archive']
    with (out / 'results.csv').open('w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fields, extrasaction='ignore')
        writer.writeheader()
        writer.writerows(results)
    lines = [f'# {kind} results', '',
             'Equivalence here means bounded cycle agreement, not a formal proof. Unknown costs remain N/A.', '',
             '| Design | Checks | Golden | Lint clean | Synth | Overall |',
             '|---|---:|---:|---:|---:|---:|']
    for d in PORTS:
        rs = [r for r in results if r['design'] == d]
        counts = [sum(r[k] == 'pass' for r in rs) for k in ('equivalence', 'lint', 'synthesis')]
        lines.append(f'| {d} | {len(rs)} | ' + ' | '.join(f'{c}/{len(rs)}' for c in counts) + f' | {sum(r["overall_pass"] for r in rs)}/{len(rs)} |')
    lines += ['', '| Design | Seed | Golden | Lint | Synth | Retries | Tokens | Generation s | Check s | Archive |',
              '|---|---:|---|---|---|---:|---:|---:|---:|---|']
    for r in results:
        values = [r.get(k) for k in ('design','seed','equivalence','lint','synthesis','retries','tokens','generation_seconds','evaluation_seconds')]
        lines.append('| ' + ' | '.join('N/A' if v is None else str(v) for v in values) + f' | [{r["archive"]}]({r["archive"]}) |')
    (out / 'REPORT.md').write_text('\n'.join(lines) + '\n')


def inside(path):
    resolved = Path(path).resolve()
    if not resolved.is_relative_to(ROOT):
        raise ValueError('Paths must stay inside this repository')
    return resolved


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixtures', action='store_true', help='Validate harness on authored fixtures; never a pipeline score')
    parser.add_argument('--candidates', help='Root containing DESIGN/run-N/rtl/*.v and optional metadata.json')
    parser.add_argument('--out', required=True, help='New output directory; existing directories are refused')
    parser.add_argument('--runs', type=int, default=3)
    parser.add_argument('--timeout', type=float, default=60)
    args = parser.parse_args()
    if bool(args.fixtures) == bool(args.candidates):
        parser.error('Choose exactly one of --fixtures or --candidates')
    if args.runs < 3 or args.timeout <= 0:
        parser.error('At least three runs and a positive timeout are required')
    try:
        out = inside(args.out)
        candidates = inside(args.candidates) if args.candidates else ROOT / 'fixtures'
        out.mkdir(parents=True, exist_ok=False)
        versions = {}
        for name in ('iverilog', 'vvp', 'yosys'):
            cmd = tool(name)
            versions[name] = command(cmd + ['-V'] if cmd else None, out, name + '-version', args.timeout)
        results = []
        kind = 'fixture-validation' if args.fixtures else 'imported-candidates'
        for d in PORTS:
            for n in range(args.runs):
                candidate = candidates / d if args.fixtures else candidates / d / f'run-{n+1}'
                print(f'Checking {d} run-{n+1}', flush=True)
                results.append(evaluate(d, candidate, out / f'{d}-run-{n+1}', n, args.timeout, kind))
        reports(results, out, kind)
        print(out / 'REPORT.md')
        return 0 if all(r['overall_pass'] for r in results) else 1
    except (ValueError, OSError) as exc:
        parser.exit(2, f'{exc}\n')


if __name__ == '__main__':
    raise SystemExit(main())
