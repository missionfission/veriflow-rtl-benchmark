"""Create isolated requirement-only projects; never invokes a paid model."""
import argparse
import json
import shutil
from .models import PORTS
from .runner import ROOT, inside


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--out', required=True)
    p.add_argument('--runs', type=int, default=3)
    a = p.parse_args()
    if a.runs < 3:
        p.error('At least three fresh generations per design are required')
    try:
        out = inside(a.out)
        out.mkdir(parents=True, exist_ok=False)
        for design in PORTS:
            for n in range(1, a.runs+1):
                project = out / design / f'run-{n}'
                project.mkdir(parents=True)
                shutil.copyfile(ROOT / 'specs' / (design+'.md'), project / 'requirement.md')
                (project / 'metadata.template.json').write_text(json.dumps(dict(
                    run_id=f'{design}-{n}', fresh_generation=True, model=None,
                    upstream_revision='77eca651d0e6ec93ed5309060980c54e76af7432',
                    retries=None, tokens=None, generation_seconds=None), indent=2)+'\n')
        print(f'Prepared {len(PORTS)*a.runs} projects at {out}; see docs/LIVE_RUNS.md')
    except (OSError, ValueError) as exc:
        p.exit(2, f'{exc}\n')


if __name__ == '__main__':
    main()
