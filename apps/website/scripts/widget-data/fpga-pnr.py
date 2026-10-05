#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""fpga-pnr.py -- one real place-and-route run, turned into the data and cards of three widgets.

The widgets are placement-map, resource-bars and slack-waterfall (specs/widgets/<id>.t27). Every
number they draw comes from one yosys + nextpnr-xilinx run on a real bench design; this script
runs that flow (subcommand `run`) and turns its outputs into the compact JSON the widgets fetch
and the 1200x630 share cards (subcommand `build`). Nothing here invents a number: a value the
outputs do not contain is not written.

  python3 scripts/widget-data/fpga-pnr.py run   --out /tmp/widget-pnr
  python3 scripts/widget-data/fpga-pnr.py build --pnr /tmp/widget-pnr

`run` defaults (override with flags): the design is trinity_v3_jtaguart.v from trinity-fpga
fpga/openxc7-synth with its jtaguart.xdc (QMTech Wukong pins), synthesised by yosys synth_xilinx
and placed and routed by nextpnr-xilinx on the xc7a200tfbg676-1 chipdb -- the die and BGA-676
pinout of the bench's XC7A200T-FGG676 (fpga/HARDWARE_SSOT.md, 2026-07-05 note).

Timing. This nextpnr-xilinx build writes `--report` with `critical_paths: []` always (its
reportJson in common/timing.cc fills only fmax and utilization), so the per-endpoint paths come
from nextpnr's own SDF (`--sdf`): the script walks the SDF's INTERCONNECT and IOPATH delays the
way nextpnr's timing.cc walks the netlist (net max arrival + this user's routing delay + setup)
and then checks itself against nextpnr: the worst endpoint and its total must equal the critical
path nextpnr printed in its log, and the slack histogram rebuilt from these endpoints with
nextpnr's own binning must equal the histogram in the log, bin by bin. If either check fails the
build stops.

Part totals are counted from the chipdb (the `available` field nextpnr writes per BEL type in
--report) and from prjxray-db (tilegrid.json for the die, package_pins.csv for bonded pins); the
spec cross-checks them against AMD DS180.
"""
import argparse
import datetime
import hashlib
import json
import math
import os
import re
import shutil
import subprocess
import sys
from collections import Counter, defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
SITE = os.path.abspath(os.path.join(HERE, '..', '..'))
WIDGETS = os.path.join(SITE, 'public', 'widgets')
HOME = os.path.expanduser('~')

DEFAULTS = {
    'repo': os.path.join(HOME, 'trinity-fpga'),
    'src': 'fpga/openxc7-synth/trinity_v3_jtaguart.v',
    'xdc': 'fpga/openxc7-synth/jtaguart.xdc',
    'top': 'trinity_v3_jtaguart',
    'part': 'xc7a200tfbg676-1',
    'chipdb': os.path.join(HOME, 'openxc7-src/chipdb/xc7a200tfbg676-1.bin'),
    'prjxray': os.path.join(HOME, 'openxc7-src/prjxray-db-full'),
    'nextpnr': os.path.join(HOME, '.local/bin/nextpnr-xilinx'),
    'yosys': shutil.which('yosys') or '/opt/homebrew/bin/yosys',
    'freq': '50',
    'seed': '1',
}

GREEN, GOLD, TEXT, RED = (0, 255, 136), (255, 215, 0), (232, 255, 247), (255, 77, 109)


def sh(cmd, cwd=None):
    r = subprocess.run(cmd, cwd=cwd, check=True, capture_output=True, text=True)
    return (r.stdout.strip() or r.stderr.strip()).splitlines()[0]


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def home(p):
    return p.replace(HOME, '~')


# --------------------------------------------------------------------------------------------
# run: yosys + nextpnr-xilinx, every command recorded
# --------------------------------------------------------------------------------------------
def cmd_run(a):
    out = os.path.abspath(a.out)
    if out.startswith(os.path.abspath(a.repo)):
        sys.exit('fpga-pnr: build output must not go inside the design repository')
    os.makedirs(out, exist_ok=True)
    src = os.path.join(a.repo, a.src)
    xdc = os.path.join(a.repo, a.xdc)
    shutil.copy(src, os.path.join(out, os.path.basename(src)))
    shutil.copy(xdc, os.path.join(out, os.path.basename(xdc)))
    vfile, xfile = os.path.basename(src), os.path.basename(xdc)
    ys = ['yosys', '-q', '-l', 'yosys.log', '-p',
          f'synth_xilinx -flatten -abc9 -arch xc7 -top {a.top}; write_json synth.json', vfile]
    pnr = ['nextpnr-xilinx', '--chipdb', a.chipdb, '--xdc', xfile, '--json', 'synth.json',
           '--freq', a.freq, '--seed', a.seed, '--write', 'routed.json', '--report', 'report.json',
           '--sdf', 'routed.sdf', '--fasm', 'routed.fasm', '--log', 'nextpnr.log']
    subprocess.run([a.yosys] + ys[1:], cwd=out, check=True)
    subprocess.run([a.nextpnr] + pnr[1:], cwd=out, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    prov = {
        'when_utc': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d %H:%M UTC'),
        'design_repo': 'gHashTag/trinity-fpga',
        'design_commit': sh(['git', 'rev-parse', 'HEAD'], cwd=a.repo),
        'design_src': a.src,
        'design_xdc': a.xdc,
        'design_src_sha256': sha256_file(src),
        'design_xdc_sha256': sha256_file(xdc),
        'top': a.top,
        'part': a.part,
        'chipdb': home(a.chipdb),
        'chipdb_sha256': sha256_file(a.chipdb),
        'yosys_version': sh([a.yosys, '-V']),
        'nextpnr_version': sh([a.nextpnr, '--version']),
        'prjxray_db': home(a.prjxray),
        'prjxray_db_commit': sh(['git', 'rev-parse', 'HEAD'], cwd=a.prjxray),
        'commands': [' '.join(json.dumps(x) if ' ' in x or ';' in x else x for x in ys),
                     ' '.join(home(x) for x in pnr)],
        'freq_mhz': float(a.freq),
        'seed': int(a.seed),
    }
    with open(os.path.join(out, 'provenance.json'), 'w') as f:
        json.dump(prov, f, indent=2)
    print(json.dumps(prov, indent=2))


# --------------------------------------------------------------------------------------------
# nextpnr log: its critical path, fmax lines and final slack histogram
# --------------------------------------------------------------------------------------------
def parse_log(path):
    text = open(path).read()
    # The last critical path report and the last histogram are the post-route ones.
    crit_blocks = text.split('Critical path report for clock')
    last = crit_blocks[-1]
    steps = []
    for m in re.finditer(r'Info:\s+([\d.]+)\s+([\d.]+)\s+(Source|Net|Setup)\s+(\S+)', last):
        steps.append((m.group(3), float(m.group(1)), float(m.group(2)), m.group(4)))
    crit = {
        'clock': re.match(r"\s*'([^']+)'", last).group(1),
        'steps': steps,
        'total_ns': steps[-1][2] if steps else None,
        'endpoint': steps[-1][3] if steps else None,
    }
    crit['nets'] = re.findall(r'Info:\s+[\d.]+\s+[\d.]+\s+Net (\S+) budget', last)
    m = re.search(r'Info: ([\d.]+) ns logic, ([\d.]+) ns routing', last)
    if m:
        crit['logic_ns'], crit['routing_ns'] = float(m.group(1)), float(m.group(2))
    fmax = re.findall(r"Max frequency for clock '([^']+)': ([\d.]+) MHz \((PASS|FAIL) at ([\d.]+) MHz\)", text)
    hist_text = text.split('Slack histogram:')[-1]
    hist = [(int(a), int(b), len(s)) for a, b, s in re.findall(r'\[\s*(-?\d+),\s*(-?\d+)\) \|(\**)\+?', hist_text)]
    legend = re.search(r'\* represents (\d+) endpoint', hist_text)
    util = {}
    block = text.split('Device utilisation:')[-1].split('\n\n')[0]
    for name, used, avail in re.findall(r'Info:\s+(\S+):\s+(\d+)/\s*(\d+)', block):
        util[name] = (int(used), int(avail))
    return {'crit': crit, 'fmax': fmax, 'hist': hist, 'hist_per_star': int(legend.group(1)) if legend else None,
            'util': util}


# --------------------------------------------------------------------------------------------
# SDF static timing, as nextpnr's timing.cc computes it
# --------------------------------------------------------------------------------------------
def unescape(s):
    return re.sub(r'\\(.)', r'\1', s)


def split_pin(tok):
    # instance/pin, where '/' inside the instance name is escaped with a backslash
    i = len(tok) - 1
    while i >= 0:
        if tok[i] == '/' and (i == 0 or tok[i - 1] != '\\'):
            return unescape(tok[:i]), tok[i + 1:]
        i -= 1
    raise ValueError(tok)


def parse_sdf(path):
    cells = {}  # inst -> {'type', 'iopath': [(a,b,d)], 'setup': {pin: d}}
    inter = []  # (src_inst, src_pin, dst_inst, dst_pin, delay)
    cur = None
    num = r'\((-?\d+):(-?\d+):(-?\d+)\)'
    for line in open(path):
        s = line.strip()
        if s.startswith('(CELLTYPE'):
            cur = {'type': s.split('"')[1], 'iopath': [], 'setup': {}}
        elif s.startswith('(INSTANCE'):
            name = unescape(s[len('(INSTANCE'):].strip()[:-1].strip())
            cells[name] = cur
        elif s.startswith('(INTERCONNECT'):
            parts = s[len('(INTERCONNECT'):].split()
            a_inst, a_pin = split_pin(parts[0])
            b_inst, b_pin = split_pin(parts[1])
            d = [int(x) for x in re.findall(num, s)[0]]
            inter.append((a_inst, a_pin, b_inst, b_pin, max(d)))
        elif s.startswith('(IOPATH'):
            parts = s.split()
            d = [int(x) for x in re.findall(num, s)[0]]
            cur['iopath'].append((parts[1], parts[2], max(d)))
        elif s.startswith('(SETUPHOLD'):
            m = re.match(r'\(SETUPHOLD \((?:posedge|negedge) (\S+)\) \((?:posedge|negedge) (\S+)\) ' + num, s)
            if m:
                pin, setup = m.group(1), int(m.group(3))
                cur['setup'][pin] = max(cur['setup'].get(pin, 0), setup)
    return cells, inter


def sta(cells, inter, period_ps, routed_cells):
    """Per-endpoint worst arrival from the SDF, following nextpnr-xilinx's timing.cc and
    xilinx/arch.cc getPortTimingClass for the cell types this flow produces:
      - startpoints are SLICE_FFX Q pins (arrival = the CK->Q IOPATH);
      - IOB33_* and PAD cells are TMG_IGNORE in this arch, so pads start nothing and end
        nothing, and constant drivers (PSEUDO_VCC/GND) are false startpoints;
      - an output pin's arrival is the max over its timed inputs of (driver arrival +
        INTERCONNECT delay + IOPATH delay); an input wired to its own cell's output is skipped;
      - endpoints are SLICE_FFX D/CE/SR with a timed driver: slack = period - (arrival +
        INTERCONNECT delay + SETUPHOLD setup).
    Returns (endpoints, pred, arrival); every endpoint is
    (slack_ps, total_ps, inst, pin, driver_node, route_ps, setup_ps)."""
    driver = {}  # (inst, inpin) -> ((inst, outpin), delay)
    for a_i, a_p, b_i, b_p, d in inter:
        driver[(b_i, b_p)] = ((a_i, a_p), d)
    arcs_in = defaultdict(list)  # (inst, outpin) -> [(inpin, delay)]
    for inst, c in cells.items():
        for a, b, d in c['iopath']:
            if a in ('CK', 'CLK'):
                continue
            arcs_in[(inst, b)].append((a, d))
    arrival, pred = {}, {}
    visiting = set()

    def arr(node):
        if node in arrival:
            return arrival[node]
        inst, pin = node
        c = cells.get(inst)
        if c is None:
            return None
        if c['type'] == 'SLICE_FFX':
            v = None
            for a, b, d in c['iopath']:
                if a == 'CK' and b == pin:
                    v = d
                    pred[node] = ('clk-to-q', None, d)
            arrival[node] = v
            return v
        if node in visiting:  # a combinational loop: nextpnr ignores loops by default
            return None
        visiting.add(node)
        best = None
        for inpin, d in arcs_in.get(node, []):
            drv = driver.get((inst, inpin))
            if drv is None or drv[0] == node:
                continue
            t = arr(drv[0])
            if t is None:
                continue
            cand = t + drv[1] + d
            if best is None or cand > best:
                best = cand
                pred[node] = ('logic', (drv[0], inst, inpin, drv[1]), d)
        visiting.discard(node)
        arrival[node] = best
        return best

    endpoints = []
    for inst, c in cells.items():
        if c['type'] != 'SLICE_FFX':
            continue
        for pin, setup in c['setup'].items():
            drv = driver.get((inst, pin))
            if drv is None:
                continue
            t = arr(drv[0])
            if t is None:
                continue
            total = t + drv[1] + setup
            endpoints.append((period_ps - total, total, inst, pin, drv[0], drv[1], setup))
    return endpoints, pred, arrival


def walk_back(ep, pred, cells):
    """Segments of the worst path into one endpoint, source first."""
    slack, total, inst, pin, drv, d_last, setup = ep
    segs = [('setup', inst, pin, inst, pin, setup), ('routing', drv[0], drv[1], inst, pin, d_last)]
    node = drv
    while True:
        kind, info, d = pred[node]
        if kind == 'clk-to-q':
            segs.append(('clk-to-q', node[0], 'CK', node[0], node[1], d))
            break
        src_node, b_i, b_p, rd = info
        segs.append(('logic', b_i, b_p, node[0], node[1], d))
        segs.append(('routing', src_node[0], src_node[1], b_i, b_p, rd))
        node = src_node
    segs.reverse()
    return segs


def histogram(slacks, num_bins=20, bar_width=60):
    """nextpnr's own binning (common/timing.cc timing_analysis)."""
    freq = Counter(slacks)
    lo, hi = min(freq), max(freq)
    bin_size = max(1, math.ceil((hi - lo + 1) / float(num_bins)))
    bins = [0] * num_bins
    for k, n in freq.items():
        bins[(k - lo) // bin_size] += n
    max_freq = max(bins)
    bw = min(bar_width, max_freq)
    return [(lo + i * bin_size, lo + (i + 1) * bin_size, bins[i] * bw // max_freq) for i in range(num_bins)], bins


# --------------------------------------------------------------------------------------------
# die geometry from prjxray-db
# --------------------------------------------------------------------------------------------
TILE_KINDS = [('CLBLL', 'clbll'), ('CLBLM', 'clblm'), ('BRAM_L', 'bram'), ('BRAM_R', 'bram'),
              ('DSP_L', 'dsp'), ('DSP_R', 'dsp'), ('LIOB33', 'iob'), ('RIOB33', 'iob'),
              ('CLK_BUFG', 'bufg'), ('CMT_TOP', 'cmt'), ('GTP_CHANNEL', 'gtp'), ('PCIE_BOT', 'pcie')]
SPAN = {'clbll': 1, 'clblm': 1, 'bram': 5, 'dsp': 5, 'iob': 2, 'bufg': 4, 'cmt': 1, 'gtp': 1, 'pcie': 1}


def kind_of(tile_type):
    for prefix, k in TILE_KINDS:
        if tile_type.startswith(prefix) and 'INT' not in tile_type:
            return k
    return None


def die_geometry(tilegrid_path, package_path):
    t = json.load(open(tilegrid_path))
    gw = max(v['grid_x'] for v in t.values()) + 1
    gh = max(v['grid_y'] for v in t.values()) + 1
    cols = defaultdict(list)  # (kind, gx) -> [gy]
    site_xy = {}
    for name, v in t.items():
        k = kind_of(v['type'])
        if k is None:
            continue
        span = 2 if v['type'].endswith('_SING') is False and k == 'iob' else (1 if k == 'iob' else SPAN[k])
        cols[(k, v['grid_x'])].append((v['grid_y'], span))
        for s in v['sites']:
            site_xy[s] = (v['grid_x'], v['grid_y'], k, span)
    runs = []
    for (k, gx), ys in sorted(cols.items(), key=lambda kv: (kv[0][1], kv[0][0])):
        ys.sort()
        # runs of [top_gy, bottom_gy] covering tile spans (a tile at gy with span s covers gy-s+1..gy)
        cur = None
        for gy, span in ys:
            top = gy - span + 1
            if cur and top <= cur[1] + 1:
                cur[1] = max(cur[1], gy)
            else:
                if cur:
                    runs.append([k, gx, cur[0], cur[1]])
                cur = [top, gy]
        runs.append([k, gx, cur[0], cur[1]])

    # Site index -> grid, per site family; checked to be a pure function of one coordinate.
    def axis_map(prefix, coord):
        out = {}
        for s, (gx, gy, k, span) in site_xy.items():
            m = re.match(prefix + r'_X(\d+)Y(\d+)$', s)
            if not m:
                continue
            key = int(m.group(1 if coord == 'x' else 2))
            val = gx if coord == 'x' else gy
            if key in out and out[key] != val:
                raise SystemExit(f'fpga-pnr: {prefix} {coord}={key} maps to two grid lines')
            out[key] = val
        n = max(out) + 1
        return [out.get(i, -1) for i in range(n)]

    maps = {}
    for fam in ['SLICE', 'RAMB36', 'RAMB18', 'DSP48', 'IOB', 'BUFGCTRL']:
        maps[fam] = {'x': axis_map(fam, 'x'), 'y': axis_map(fam, 'y')}
    bonded = 0
    with open(package_path) as f:
        next(f)
        for line in f:
            if line.split(',')[2].startswith('IOB_'):
                bonded += 1
    counts = Counter()
    for s, (gx, gy, k, span) in site_xy.items():
        fam = re.match(r'([A-Z0-9]+)_X', s)
        if fam:
            counts[fam.group(1)] += 1
    return {'grid_w': gw, 'grid_h': gh, 'runs': runs, 'maps': maps}, {
        'slices': counts['SLICE'], 'ramb36': counts['RAMB36'], 'ramb18': counts['RAMB18'],
        'dsp48': counts['DSP48'], 'iob_die': counts['IOB'], 'iob_bonded': bonded,
        'bufgctrl': counts['BUFGCTRL']}


# --------------------------------------------------------------------------------------------
# build: compact JSON + cards
# --------------------------------------------------------------------------------------------
def cell_kind(ctype):
    """The colour class a placed cell is drawn in."""
    if ctype == 'SLICE_LUTX':
        return 'LUT'
    if ctype == 'SLICE_FFX':
        return 'FF'
    if ctype == 'CARRY4':
        return 'CARRY4'
    if ctype.startswith('RAMB') or ctype.startswith('FIFO'):
        return 'BRAM'
    if ctype.startswith('DSP48'):
        return 'DSP'
    if ctype.startswith('IOB') or ctype == 'PAD':
        return 'IO'
    if ctype.startswith('BUFG'):
        return 'BUFG'
    return 'OTHER'


def resources_of(cells):
    """Used resources, counted the way the chipdb counts sites (shared with tool.js)."""
    lut6 = set()
    slices = set()
    n = Counter()
    for name, ctype, bel in cells:
        site, _, belname = bel.partition('/')
        if ctype in ('SLICE_LUTX', 'SLICE_FFX', 'CARRY4'):
            slices.add(site)
        if ctype == 'SLICE_LUTX':
            lut6.add((site, belname[:1]))
        n[ctype] += 1
    return {
        'LUT': len(lut6), 'FF': n['SLICE_FFX'], 'CARRY4': n['CARRY4'], 'SLICE': len(slices),
        'BRAM36': sum(v for k, v in n.items() if k.startswith(('RAMB36', 'RAMBFIFO36', 'FIFO36'))),
        'BRAM18': sum(v for k, v in n.items() if k.startswith(('RAMB18', 'FIFO18'))),
        'DSP48': sum(v for k, v in n.items() if k.startswith('DSP48')), 'IOB': n['PAD'],
        'BUFG': n['BUFGCTRL'] + n['BUFG'],
        'LUT_CELLS': n['SLICE_LUTX'],
    }


def font(size, bold=False, mono=False):
    from PIL import ImageFont
    cands = (['/System/Library/Fonts/Menlo.ttc', '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'] if mono else
             (['/System/Library/Fonts/Supplemental/Arial Bold.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'] if bold else
              ['/System/Library/Fonts/Supplemental/Arial.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf']))
    for c in cands:
        if os.path.exists(c):
            return ImageFont.truetype(c, size, index=1 if (mono and bold and c.endswith('.ttc')) else 0)
    return ImageFont.load_default()


def card_frame(title, number, note):
    """Black 1200x630 card: brand with a point-down triangle, title, one real number."""
    from PIL import Image, ImageDraw
    img = Image.new('RGB', (1200, 630), (0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(48, 44), (72, 44), (60, 64)], fill=GREEN)
    d.text((84, 40), 'Trinity S³AI', font=font(26, bold=True), fill=GREEN)
    d.text((48, 92), title, font=font(40, bold=True), fill=TEXT)
    d.text((48, 548), number, font=font(44, bold=True), fill=GOLD)
    d.text((48, 600), note, font=font(17, mono=True), fill=(143, 169, 160))
    return img, d


def save_card(img, path):
    img.save(path, optimize=True)
    size = os.path.getsize(path)
    if size > 1024 * 1024:
        img.convert('P', palette=1, colors=128).save(path, optimize=True)
    return os.path.getsize(path)


KIND_RGB = {'LUT': GREEN, 'FF': GOLD, 'CARRY4': (0, 180, 255), 'BRAM': (190, 120, 255), 'DSP': (255, 140, 60),
            'IO': (255, 77, 109), 'BUFG': (255, 255, 255), 'OTHER': (120, 120, 120)}
BG_RGB = {'clbll': (16, 30, 24), 'clblm': (20, 38, 30), 'bram': (40, 26, 56), 'dsp': (52, 34, 16),
          'iob': (50, 20, 28), 'bufg': (60, 60, 60), 'cmt': (30, 30, 30), 'gtp': (26, 26, 40), 'pcie': (26, 26, 40)}


def bel_xy(bel, maps):
    site = bel.split('/')[0]
    m = re.match(r'([A-Z0-9]+)_X(\d+)Y(\d+)$', site)
    if not m:
        return None
    fam, x, y = m.group(1), int(m.group(2)), int(m.group(3))
    if fam == 'FIFO18' or fam == 'RAMB18':
        fam = 'RAMB18'
    mp = maps.get(fam)
    if not mp or x >= len(mp['x']) or y >= len(mp['y']) or mp['x'][x] < 0 or mp['y'][y] < 0:
        return None
    return mp['x'][x], mp['y'][y], x, y


def draw_die(img, box, geom, cells, zoom_box=None, mark=2):
    from PIL import ImageDraw
    d = ImageDraw.Draw(img)
    x0, y0, w, h = box
    gx0, gy0, gw, gh = zoom_box or (0, 0, geom['grid_w'], geom['grid_h'])
    sx, sy = w / gw, h / gh
    for k, gx, top, bot in geom['runs']:
        if gx < gx0 or gx >= gx0 + gw:
            continue
        a, b = max(top, gy0), min(bot, gy0 + gh - 1)
        if a > b:
            continue
        px = x0 + (gx - gx0) * sx
        d.rectangle([px, y0 + (a - gy0) * sy, px + max(1, sx * 0.8), y0 + (b - gy0 + 1) * sy - 1], fill=BG_RGB[k])
    for name, ctype, bel in cells:
        p = bel_xy(bel, geom['maps'])
        if not p:
            continue
        gx, gy, sxi, syi = p
        if not (gx0 <= gx < gx0 + gw and gy0 <= gy < gy0 + gh):
            continue
        k = cell_kind(ctype)
        half = (sxi % 2) * 0.45 if ctype in ('SLICE_LUTX', 'SLICE_FFX', 'CARRY4') else 0
        px = x0 + (gx - gx0 + half) * sx
        py = y0 + (gy - gy0) * sy
        r = max(mark, min(sx, sy) * 0.42)
        d.rectangle([px, py, px + r, py + r], fill=KIND_RGB[k])


def cmd_build(a):
    pnr = os.path.abspath(a.pnr)
    prov = json.load(open(os.path.join(pnr, 'provenance.json')))
    routed = json.load(open(os.path.join(pnr, 'routed.json')))
    report = json.load(open(os.path.join(pnr, 'report.json')))
    log = parse_log(os.path.join(pnr, 'nextpnr.log'))
    xray = os.path.join(a.prjxray, 'artix7')
    geom, die = die_geometry(os.path.join(xray, 'xc7a200t', 'tilegrid.json'),
                             os.path.join(xray, prov['part'], 'package_pins.csv'))
    top = routed['modules']['top']
    cells = sorted((n, c['type'], c['attributes'].get('NEXTPNR_BEL', '')) for n, c in top['cells'].items())
    used = resources_of(cells)
    util = report['utilization']
    avail = {k: v['available'] for k, v in util.items()}

    # Chipdb counts (nextpnr --report 'available') against prjxray-db counts: they must agree.
    checks = {
        'slices_chipdb_carry4': avail['CARRY4'], 'slices_prjxray': die['slices'],
        'lutx_bels_chipdb': avail['SLICE_LUTX'], 'ffx_bels_chipdb': avail['SLICE_FFX'],
        'ramb36_chipdb': avail['RAMB36E1_RAMB36E1'], 'ramb36_prjxray': die['ramb36'],
        'ramb18_chipdb': avail['RAMB18E1_RAMB18E1'], 'ramb18_prjxray': die['ramb18'],
        'dsp48_chipdb': avail['DSP48E1_DSP48E1'] if 'DSP48E1_DSP48E1' in avail else avail.get('DSP48E1'),
        'dsp48_prjxray': die['dsp48'], 'bufgctrl_chipdb': avail['BUFGCTRL'], 'bufgctrl_prjxray': die['bufgctrl'],
        'pad_chipdb': avail['PAD'], 'iob_die_prjxray': die['iob_die'], 'iob_bonded_package': die['iob_bonded'],
    }
    assert checks['slices_chipdb_carry4'] == checks['slices_prjxray'], checks
    assert checks['ramb36_chipdb'] == checks['ramb36_prjxray'], checks
    assert checks['ramb18_chipdb'] == checks['ramb18_prjxray'], checks
    assert checks['dsp48_chipdb'] == checks['dsp48_prjxray'], checks
    assert checks['bufgctrl_chipdb'] == checks['bufgctrl_prjxray'], checks
    assert checks['lutx_bels_chipdb'] == 8 * checks['slices_prjxray'], checks
    totals = {'LUT': 4 * die['slices'], 'FF': avail['SLICE_FFX'], 'CARRY4': avail['CARRY4'], 'SLICE': die['slices'],
              'BRAM36': die['ramb36'], 'BRAM18': die['ramb18'], 'DSP48': die['dsp48'],
              'IOB': die['iob_bonded'], 'BUFG': die['bufgctrl']}
    # nextpnr's own log line for the same counts.
    assert log['util']['SLICE_LUTX'][0] == used['LUT_CELLS'], (log['util']['SLICE_LUTX'], used)
    assert log['util']['SLICE_FFX'][0] == used['FF']
    assert log['util']['CARRY4'][0] == used['CARRY4']

    source = {
        'design': f"{prov['design_repo']} {prov['design_src']} @ {prov['design_commit'][:10]}",
        'xdc': prov['design_xdc'], 'top': prov['top'], 'part': prov['part'],
        'chipdb': os.path.basename(prov['chipdb']),
        'nextpnr': 'nextpnr-xilinx ' + re.search(r'Version (\S+?)\)', prov['nextpnr_version']).group(1),
        'yosys': 'yosys ' + re.search(r'Yosys (\S+)', prov['yosys_version']).group(1) + ' ' +
                 re.search(r'sha1 ([0-9a-f]{10})', prov['yosys_version']).group(1), 'commands': prov['commands'], 'when': prov['when_utc'],
        'prjxray_db': prov['prjxray_db_commit'][:10],
    }

    # ---- placement-map ----------------------------------------------------------------------
    names = [c[0] for c in cells]
    pm = {'t27': 'placement-map/1', 'source': source, 'die': 'xc7a200t', 'geometry': geom,
          'cells': [[c[0], c[1], c[2]] for c in cells]}
    off_map = [c for c in cells if not bel_xy(c[2], geom['maps'])]
    pm['off_map'] = [[c[0], c[1], c[2]] for c in off_map]
    write_json(os.path.join(WIDGETS, 'placement-map', 'placement.json'), pm)

    # ---- resource-bars ----------------------------------------------------------------------
    rb = {'t27': 'resource-bars/1', 'source': source, 'cells': len(cells), 'used': used, 'totals': totals, 'checks': checks,
          'nextpnr_util': {k: list(v) for k, v in log['util'].items() if v[0] > 0}}
    write_json(os.path.join(WIDGETS, 'resource-bars', 'resources.json'), rb)

    # ---- slack-waterfall --------------------------------------------------------------------
    period_ps = int(round(1e6 / prov['freq_mhz']))
    sdf_cells, inter = parse_sdf(os.path.join(pnr, 'routed.sdf'))
    endpoints, pred, _ = sta(sdf_cells, inter, period_ps, top['cells'])
    endpoints.sort(key=lambda e: (e[0], e[2], e[3]))
    slacks_ps = [int(e[0]) for e in endpoints]
    mine, mine_bins = histogram(slacks_ps)
    theirs = log['hist']
    hist_ok = (log['hist_per_star'] == 1 and len(mine) == len(theirs) and
               all(m[0] == t[0] and m[1] == t[1] and m[2] == t[2] for m, t in zip(mine, theirs)))
    worst = endpoints[0]
    crit = log['crit']
    worst_ok = (crit['endpoint'] == f'{worst[2]}.{worst[3]}' and abs(crit['total_ns'] - worst[1] / 1000) < 0.051)
    if not (hist_ok and worst_ok):
        print('mine  ', mine, file=sys.stderr)
        print('theirs', theirs, file=sys.stderr)
        print('worst', worst[:4], 'nextpnr', crit['endpoint'], crit['total_ns'], file=sys.stderr)
        sys.exit('fpga-pnr: the SDF walk does not reproduce nextpnr; refusing to publish its paths')
    net_of = {}
    for n, c in top['cells'].items():
        for p, bits in c['connections'].items():
            if c['port_directions'].get(p) == 'output' and bits:
                net_of[(n, p)] = bits[0]
    bitname = {}
    for nn, v in top['netnames'].items():
        for b in v['bits']:
            if b not in bitname or (nn.startswith('$') and not bitname[b].startswith('$')) is False and len(nn) < len(bitname[b]):
                bitname[b] = nn
    strings = {}

    def sid(s):
        if s not in strings:
            strings[s] = len(strings)
        return strings[s]

    paths = []
    logic_total = routing_total = 0
    for ep in endpoints:
        segs = walk_back(ep, pred, sdf_cells)
        out = []
        for kind, fi, fp, ti, tp, dly in segs:
            net = bitname.get(net_of.get((fi, fp))) if kind == 'routing' else None
            out.append([kind, int(dly), sid(fi), fp, sid(ti), tp, sid(net) if net else -1])
        assert sum(s[1] for s in out) == ep[1], (ep, out)
        paths.append({'to': sid(ep[2]), 'pin': ep[3], 'slack': int(ep[0]), 'total': int(ep[1]), 'segs': out})
    w = paths[0]
    w_nets = [sw_s for sw_s in (s[6] for s in w['segs'] if s[0] == 'routing')]
    w_nets = [[k for k, v in strings.items() if v == i][0] for i in w_nets]
    if w_nets != crit['nets']:
        sys.exit(f"fpga-pnr: worst path nets differ from nextpnr's: {w_nets} vs {crit['nets']}")
    w_logic = sum(s[1] for s in w['segs'] if s[0] != 'routing')
    w_route = sum(s[1] for s in w['segs'] if s[0] == 'routing')
    fmax = {k: v for k, v in report['fmax'].items()}
    sw = {'t27': 'slack-waterfall/1', 'source': source, 'period_ps': period_ps, 'freq_mhz': prov['freq_mhz'],
          'fmax': fmax, 'clock_net': crit['clock'],
          'check': {'nextpnr_critical_endpoint': crit['endpoint'], 'nextpnr_critical_total_ns': crit['total_ns'],
                    'nextpnr_logic_ns': crit.get('logic_ns'), 'nextpnr_routing_ns': crit.get('routing_ns'),
                    'sdf_worst_total_ps': w['total'], 'sdf_worst_logic_ps': w_logic, 'sdf_worst_routing_ps': w_route,
                    'endpoints': len(paths), 'worst_path_nets_equal': True, 'histogram_bins_equal': hist_ok, 'worst_endpoint_equal': worst_ok,
                    'nextpnr_histogram': theirs, 'report_critical_paths': len(report['critical_paths'])},
          'strings': [s for s, _ in sorted(strings.items(), key=lambda kv: kv[1])], 'paths': paths}
    write_json(os.path.join(WIDGETS, 'slack-waterfall', 'timing.json'), sw)

    # ---- cards ------------------------------------------------------------------------------
    cards(geom, cells, used, totals, sw, source)
    summary = {'cells': len(cells), 'types': Counter(c[1] for c in cells), 'used': used, 'totals': totals,
               'endpoints': len(paths), 'worst_slack_ps': w['slack'], 'worst_total_ps': w['total'],
               'worst_logic_ps': w_logic, 'worst_routing_ps': w_route, 'fmax': fmax, 'off_map': len(off_map),
               'checks': checks}
    print(json.dumps(summary, indent=2, default=dict))


def write_json(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as f:
        json.dump(obj, f, separators=(',', ':'))
        f.write('\n')
    size = os.path.getsize(path)
    assert size <= 1_500_000, f'{path} is {size} bytes, over 1.5 MB'
    print(f'wrote {os.path.relpath(path, SITE)} ({size} bytes)', file=sys.stderr)


def design_box(geom, cells, pad=6):
    pts = [bel_xy(b, geom['maps']) for _, t, b in cells if t in ('SLICE_LUTX', 'SLICE_FFX', 'CARRY4')]
    pts = [p for p in pts if p]
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    x0, x1, y0, y1 = min(xs) - pad, max(xs) + pad + 1, min(ys) - pad, max(ys) + pad + 1
    return max(0, x0), max(0, y0), x1 - max(0, x0), y1 - max(0, y0)


def cards(geom, cells, used, totals, sw, source):
    from PIL import ImageDraw
    # placement-map: the whole die, and the design's corner of it enlarged
    n_cells = len([c for c in cells if bel_xy(c[2], geom['maps'])])
    img, d = card_frame('Where nextpnr put every cell, XC7A200T',
                        f"{used['SLICE']} of {totals['SLICE']:,} slices",
                        f"{source['top']} | {source['part']} | {source['nextpnr']}")
    die_box = (48, 160, 360, 360)
    draw_die(img, die_box, geom, cells)
    zb = design_box(geom, cells)
    # the enlarged window keeps the die's aspect; outline it on the die
    zh = max(zb[3], int(round(zb[2] * 360 / 700)))
    zw = max(zb[2], int(round(zh * 700 / 360)))
    zb = (max(0, zb[0] - (zw - zb[2]) // 2), max(0, zb[1] - (zh - zb[3]) // 2), zw, zh)
    sx, sy = die_box[2] / geom['grid_w'], die_box[3] / geom['grid_h']
    d.rectangle([die_box[0] + zb[0] * sx, die_box[1] + zb[1] * sy, die_box[0] + (zb[0] + zb[2]) * sx,
                 die_box[1] + (zb[1] + zb[3]) * sy], outline=GOLD, width=2)
    draw_die(img, (450, 160, 700, 360), geom, cells, zoom_box=zb, mark=5)
    d.rectangle([450, 160, 1150, 520], outline=GOLD, width=2)
    lx = 600
    for k in ['LUT', 'FF', 'CARRY4', 'IO', 'BUFG']:
        d.rectangle([lx, 562, lx + 16, 578], fill=KIND_RGB[k])
        d.text((lx + 22, 558), k, font=font(20, mono=True), fill=TEXT)
        lx += 22 + 14 * len(k) + 30
    print('card placement-map', save_card(img, os.path.join(WIDGETS, 'placement-map', 'card.png')), file=sys.stderr)

    # resource-bars
    rows = [('LUT', 'LUT'), ('FF', 'FF'), ('CARRY4', 'CARRY4'), ('SLICE', 'Slices'), ('BRAM36', 'BRAM36'),
            ('DSP48', 'DSP48'), ('IOB', 'IOB'), ('BUFG', 'BUFG')]
    img, d = card_frame('LUT, FF and BRAM against the XC7A200T',
                        f"{used['LUT']} of {totals['LUT']:,} LUTs ({100 * used['LUT'] / totals['LUT']:.2f}%)",
                        f"{source['top']} | {source['part']} | {source['nextpnr']}")
    y = 160
    for key, label in rows:
        u, t = used[key], totals[key]
        frac = u / t if t else 0
        d.text((48, y), label, font=font(24, mono=True), fill=TEXT)
        d.rectangle([220, y + 4, 900, y + 28], outline=(0, 90, 50), width=1)
        wpx = 680 * frac
        if u > 0:
            wpx = max(wpx, 3)
        d.rectangle([220, y + 4, 220 + wpx, y + 28], fill=GOLD if frac >= 0.02 else GREEN)
        d.text((920, y), f'{u:,} / {t:,}', font=font(22, mono=True), fill=TEXT)
        y += 46
    print('card resource-bars', save_card(img, os.path.join(WIDGETS, 'resource-bars', 'card.png')), file=sys.stderr)

    # slack-waterfall
    paths = sw['paths']
    period = sw['period_ps']
    fm = list(sw['fmax'].values())[0]
    img, d = card_frame(f"Every timing path, worst first, at {sw['freq_mhz']:g} MHz",
                        f"worst slack +{paths[0]['slack'] / 1000:.3f} ns, fmax {fm['achieved']:.2f} MHz",
                        f"{len(paths)} endpoints | {source['part']} | {source['nextpnr']}")
    x0, x1, y0, y1 = 48, 1150, 160, 520
    scale = (x1 - x0) / period
    rh = (y1 - y0) / len(paths)
    for i, p in enumerate(paths):
        x = x0
        yy = y0 + i * rh
        d.rectangle([x0 + p['total'] * scale, yy, x0 + period * scale, yy + max(1, rh - 0.5)], fill=(0, 46, 28))
        for s in p['segs']:
            wpx = s[1] * scale
            col = GREEN if s[0] == 'routing' else (GOLD if s[0] in ('logic', 'clk-to-q') else (200, 200, 200))
            d.rectangle([x, yy, x + wpx, yy + max(1, rh - 0.5)], fill=col)
            x += wpx
    d.line([x0 + period * scale - 1, y0 - 6, x0 + period * scale - 1, y1 + 6], fill=RED, width=2)
    d.text((700, 524), 'logic', font=font(18, mono=True), fill=GOLD)
    d.text((770, 524), 'routing', font=font(18, mono=True), fill=GREEN)
    d.text((870, 524), 'slack', font=font(18, mono=True), fill=(0, 140, 84))
    d.text((940, 524), f'{period / 1000:g} ns period', font=font(18, mono=True), fill=RED)
    print('card slack-waterfall', save_card(img, os.path.join(WIDGETS, 'slack-waterfall', 'card.png')), file=sys.stderr)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest='cmd', required=True)
    r = sub.add_parser('run')
    r.add_argument('--out', required=True)
    for k in ['repo', 'src', 'xdc', 'top', 'part', 'chipdb', 'prjxray', 'nextpnr', 'yosys', 'freq', 'seed']:
        r.add_argument('--' + k, default=DEFAULTS[k])
    b = sub.add_parser('build')
    b.add_argument('--pnr', required=True)
    b.add_argument('--prjxray', default=DEFAULTS['prjxray'])
    a = ap.parse_args()
    {'run': cmd_run, 'build': cmd_build}[a.cmd](a)


if __name__ == '__main__':
    main()
