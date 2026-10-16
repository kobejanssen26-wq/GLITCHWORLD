#!/usr/bin/env python3
"""Synthesises the original NEONFORGE soundtrack (7 music loops) and 13 sound effects with numpy only, then encodes
them to Ogg Vorbis with ffmpeg. Deterministic: same output on every run.   usage: make_audio.py out_dir"""
import sys, os, wave, subprocess, math
import numpy as np

SR = 44100
rng_global = np.random.default_rng(1234)

def mtof(m): return 440.0 * 2 ** ((m - 69) / 12)

# ---------- primitives ----------
def phase_osc(freq, n, shape='saw', detune=0.0):
    f = np.full(n, freq * (1 + detune)) if np.isscalar(freq) else freq * (1 + detune)
    ph = np.cumsum(f) / SR
    x = ph % 1.0
    if shape == 'saw': return 2 * x - 1
    if shape == 'square': return np.where(x < 0.5, 1.0, -1.0)
    if shape == 'tri': return 4 * np.abs(x - 0.5) - 1
    return np.sin(2 * np.pi * ph)

def adsr(n, a, d, s, r):
    a, d, r = int(a * SR), int(d * SR), int(r * SR)
    env = np.ones(n) * s
    a = min(a, n); env[:a] = np.linspace(0, 1, a, endpoint=False) if a else 1
    dd = min(d, max(0, n - a))
    if dd: env[a:a + dd] = np.linspace(1, s, dd)
    r = min(r, n)
    if r: env[n - r:] *= np.linspace(1, 0, r)
    return env

def fft_filter(x, lo=None, hi=None, order=2):
    """zero-phase brick-ish filter: keep lo..hi Hz (soft edges)"""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    g = np.ones_like(f)
    if hi: g *= 1 / (1 + (f / hi) ** (2 * order))
    if lo: g *= 1 - 1 / (1 + (f / lo) ** (2 * order))
    return np.fft.irfft(X * g, len(x))

def lowpass_seg(x, cutoff):
    return fft_filter(x, hi=cutoff)

# ---------- instruments (return mono float arrays of length n) ----------
def inst_bass(freq, n):
    t = phase_osc(freq, n, 'saw') * 0.6 + phase_osc(freq, n, 'sine') * 0.8 + phase_osc(freq * 2, n, 'square') * 0.1
    return lowpass_seg(t, 900) * adsr(n, 0.004, 0.12, 0.7, 0.05)

def inst_pluck(freq, n, bright=3000):
    t = phase_osc(freq, n, 'saw') * 0.5 + phase_osc(freq * 1.004, n, 'square') * 0.35 + phase_osc(freq * 2, n, 'tri') * 0.2
    t = lowpass_seg(t, bright)
    return t * adsr(n, 0.002, 0.18, 0.18, 0.08)

def inst_pad(freq, n):
    t = sum(phase_osc(freq, n, 'saw', d) for d in (-0.006, 0.0, 0.007)) / 3 + phase_osc(freq / 2, n, 'sine') * 0.5
    return lowpass_seg(t, 1800) * adsr(n, 0.5, 0.4, 0.8, 0.6)

def inst_lead(freq, n, shape='square'):
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * np.arange(n) / SR) * np.minimum(1, np.arange(n) / (0.15 * SR))
    t = phase_osc(freq * vib, n, shape) * 0.5 + phase_osc(freq * vib * 2.003, n, 'tri') * 0.2
    return lowpass_seg(t, 4200) * adsr(n, 0.01, 0.1, 0.65, 0.12)

def inst_bell(freq, n):
    out = np.zeros(n)
    for k, (m, a, d) in enumerate(((1, 1.0, 1.6), (2.76, 0.5, 1.0), (5.4, 0.3, 0.6), (8.93, 0.15, 0.4))):
        env = np.exp(-np.arange(n) / SR / (d * 0.5))
        out += a * env * np.sin(2 * np.pi * freq * m * np.arange(n) / SR)
    return out * 0.5

def kick(n=int(0.28 * SR)):
    t = np.arange(n) / SR
    f = 45 + 110 * np.exp(-t * 28)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 11) * 1.1

def snare(n=int(0.22 * SR)):
    t = np.arange(n) / SR
    noise = rng_global.standard_normal(n)
    noise = fft_filter(noise, lo=1200)
    return (noise * np.exp(-t * 20) * 0.8 + np.sin(2 * np.pi * 185 * t) * np.exp(-t * 28) * 0.5)

def hat(n=int(0.06 * SR), open_=False):
    n = int(0.22 * SR) if open_ else n
    t = np.arange(n) / SR
    noise = fft_filter(rng_global.standard_normal(n), lo=6500)
    return noise * np.exp(-t * (14 if open_ else 70)) * 0.45

def clap():
    n = int(0.16 * SR); t = np.arange(n) / SR
    noise = fft_filter(rng_global.standard_normal(n), lo=900, hi=7000)
    env = np.exp(-t * 26) * (1 + 0.8 * (np.sin(2 * np.pi * 90 * t) > 0.3))
    return noise * env * 0.7

def add(buf, start, sig, gain=1.0, pan=0.0):
    n = len(sig)
    end = min(len(buf), start + n)
    if end <= start: return
    seg = sig[: end - start] * gain
    buf[start:end, 0] += seg * (1 - max(0, pan)) * 1.0
    buf[start:end, 1] += seg * (1 + min(0, pan)) * 1.0

# ---------- composition ----------
SCALES = {
    'major': [0, 2, 4, 5, 7, 9, 11], 'minor': [0, 2, 3, 5, 7, 8, 10], 'dorian': [0, 2, 3, 5, 7, 9, 10], 'mixo': [0, 2, 4, 5, 7, 9, 10],
    'phryg': [0, 1, 3, 5, 7, 8, 10], 'lydian': [0, 2, 4, 6, 7, 9, 11],
}

def degree_note(root, scale, deg, octave=0):
    s = SCALES[scale]
    o, i = divmod(deg, 7)
    return root + s[i] + 12 * (o + octave)

def chord(root, scale, deg, sev=False):
    ns = [degree_note(root, scale, deg + k) for k in (0, 2, 4)]
    if sev: ns.append(degree_note(root, scale, deg + 6))
    return ns

def render_track(spec, seed):
    rng = np.random.default_rng(seed)
    bpm, root, scale = spec['bpm'], spec['root'], spec['scale']
    beat = 60 / bpm
    bar = 4 * beat
    bars = spec.get('bars', 32)
    step = beat / 4  # 16th
    total_n = int((bars * bar + 3.0) * SR)  # +3 s tail that gets wrapped
    mix = np.zeros((total_n, 2))
    bass_l = np.zeros((total_n, 2)); pad_l = np.zeros((total_n, 2)); kick_times = []
    prog = spec['prog']
    sections = spec.get('sections', ['a', 'b', 'c', 'd'])
    bars_per_sec = bars // len(sections)
    motif = [int(x) for x in rng.integers(0, 7, 8)]
    for b in range(bars):
        sec = sections[min(b // bars_per_sec, len(sections) - 1)]
        deg = prog[b % len(prog)]
        t0 = b * bar
        cs = chord(root, scale, deg, sev=spec.get('seventh', True))
        # pads on every section
        for k, m in enumerate(cs):
            n = int((bar + 0.8) * SR)
            add(pad_l, int(t0 * SR), inst_pad(mtof(m + 12), n), 0.14, pan=(k - 1) * 0.35)
        # bass
        bnote = degree_note(root, scale, deg, -2)
        for s16, (on, oct_) in enumerate(spec['bass']):
            if on:
                n = int(step * (spec.get('bass_len', 1.6)) * SR)
                add(bass_l, int((t0 + s16 * step) * SR), inst_bass(mtof(bnote + 12 * oct_), n), 0.5)
        # arpeggio (from section a upward)
        if spec.get('arp'):
            pattern = spec['arp']
            for s16 in range(16):
                idx = pattern[s16 % len(pattern)]
                if idx is None: continue
                m = cs[idx % len(cs)] + 12 * (1 + idx // len(cs))
                inst = inst_bell if spec.get('arp_inst') == 'bell' else inst_pluck
                n = int(step * 3.2 * SR)
                add(mix, int((t0 + s16 * step) * SR), inst(mtof(m), n), 0.2 if inst is inst_pluck else 0.22, pan=0.4 * math.sin(s16))
        # drums
        if sec in ('b', 'c', 'd') or (sec == 'a' and spec.get('drums_a')):
            dpat = spec['drums']
            for s16 in range(16):
                tt = int((t0 + s16 * step) * SR)
                if dpat['kick'][s16 % len(dpat['kick'])]:
                    add(mix, tt, kick(), 0.85); kick_times.append(tt)
                if dpat['snare'][s16 % len(dpat['snare'])]:
                    add(mix, tt, snare(), 0.5)
                if dpat.get('clap') and dpat['clap'][s16 % len(dpat['clap'])]:
                    add(mix, tt, clap(), 0.35)
                h = dpat['hat'][s16 % len(dpat['hat'])]
                if h == 1: add(mix, tt, hat(), 0.5 + 0.2 * (s16 % 2), pan=0.25 * (1 if s16 % 4 < 2 else -1))
                if h == 2: add(mix, tt, hat(open_=True), 0.45)
        # lead (sections c, d)
        if sec in ('c', 'd') and spec.get('lead', True):
            pos = 0
            rhythm = spec.get('lead_rhythm', [4, 2, 2, 4, 4])
            k = 0
            while pos < 16:
                ln = rhythm[k % len(rhythm)]
                k += 1
                if rng.random() < 0.82:
                    d_ = motif[(b * 3 + k) % len(motif)] + (deg if spec.get('lead_follow', True) else 0)
                    m = degree_note(root, scale, d_, 1 + (1 if sec == 'd' else 0))
                    n = int(step * ln * 0.95 * SR)
                    add(mix, int((t0 + pos * step) * SR), inst_lead(mtof(m), n, spec.get('lead_shape', 'square')), 0.16, pan=-0.15)
                pos += ln
    # sidechain: duck bass + pads on kicks
    duck = np.ones(total_n)
    for kt in kick_times:
        n = int(0.22 * SR)
        e = min(total_n, kt + n)
        curve = 1 - 0.65 * np.exp(-np.arange(e - kt) / (0.07 * SR))
        duck[kt:e] = np.minimum(duck[kt:e], curve)
    mix += (bass_l + pad_l) * duck[:, None]
    # reverb (synthetic impulse), stereo
    ir_n = int(1.7 * SR)
    t = np.arange(ir_n) / SR
    wet = np.zeros_like(mix)
    for c in range(2):
        ir = rng.standard_normal(ir_n) * np.exp(-t * 3.2)
        ir = fft_filter(ir, hi=5500)
        n_fft = 1 << (total_n + ir_n).bit_length()
        conv = np.fft.irfft(np.fft.rfft(mix[:, c], n_fft) * np.fft.rfft(ir, n_fft), n_fft)[:total_n]
        wet[:, c] = conv
    wet *= 0.045
    mix = mix * 0.88 + wet
    # fold the tail onto the beginning so the loop is seamless
    loop_n = int(bars * bar * SR)
    out = mix[:loop_n].copy()
    tail = mix[loop_n:]
    out[: len(tail)] += tail[: len(out)]
    # gentle master: highpass 30 Hz, soft clip, normalise to -1.5 dBFS
    for c in range(2):
        out[:, c] = fft_filter(out[:, c], lo=30)
    out = np.tanh(out * 1.25)
    out /= np.max(np.abs(out)) / 0.84
    return out

# ---------- tracks ----------
def pat(s): return [1 if ch == 'x' else 0 for ch in s.replace(' ', '')]
def bass_pat(s):  # x = root, o = octave up, . = rest
    return [(1, 0) if c == 'x' else (1, 1) if c == 'o' else (0, 0) for c in s.replace(' ', '')]

TRACKS = {
    'hub': dict(bpm=112, root=57, scale='minor', prog=[0, 5, 2, 6, 0, 5, 3, 4],
        bass=bass_pat('x..x ..x. x.o. ..x.'), arp=[0, 1, 2, 1, 2, 3, 2, 1], arp_inst='pluck',
        drums=dict(kick=pat('x... x... x... x.x.'), snare=pat('.... x... .... x...'), hat=[0, 1, 0, 1, 0, 1, 0, 2]),
        lead_rhythm=[3, 3, 2, 4, 4]),
    'zone_a': dict(bpm=122, root=60, scale='major', prog=[0, 4, 5, 3, 0, 4, 3, 4],
        bass=bass_pat('x.x. o.x. x.x. o.x.'), arp=[0, 2, 1, 3, 2, 4, 3, 1], arp_inst='pluck', lead_shape='tri',
        drums=dict(kick=pat('x... x... x... x...'), snare=pat('.... x... .... x...'), clap=pat('.... x... .... x...'), hat=[1, 0, 1, 0, 1, 0, 1, 1]),
        lead_rhythm=[2, 2, 4, 2, 2, 4]),
    'zone_b': dict(bpm=100, root=50, scale='phryg', prog=[0, 0, 5, 4, 0, 0, 6, 4],
        bass=bass_pat('x.x. .x.x x.x. .x.o'), arp=[0, None, 2, None, 1, None, 3, None], arp_inst='pluck', lead_shape='saw',
        drums=dict(kick=pat('x..x ..x. x... ..x.'), snare=pat('.... x... .... x..x'), hat=[1, 0, 1, 1, 1, 0, 1, 2]),
        lead_rhythm=[4, 4, 2, 2, 4]),
    'zone_c': dict(bpm=128, root=52, scale='minor', prog=[0, 0, 6, 5, 0, 0, 3, 6],
        bass=bass_pat('x.xx .xx. x.xx .xox'), arp=[0, 1, 2, 0, 1, 2, 3, 1], arp_inst='pluck', lead_shape='saw',
        drums=dict(kick=pat('x... x... x... x...'), snare=pat('.... .... .... ....'), clap=pat('.... x... .... x...'), hat=[0, 0, 2, 0, 0, 0, 2, 0]),
        drums_a=True, lead_rhythm=[2, 2, 2, 2, 4, 4]),
    'zone_d': dict(bpm=108, root=54, scale='dorian', prog=[0, 3, 0, 4, 5, 3, 1, 4],
        bass=bass_pat('x... ..x. .x.. o...'), arp=[0, 2, 4, 2, 1, 3, 5, 3], arp_inst='bell', lead_shape='tri',
        drums=dict(kick=pat('x... .... x... ..x.'), snare=pat('.... x... .... x...'), hat=[1, 1, 1, 1, 1, 1, 1, 1]),
        lead_rhythm=[3, 1, 4, 4, 2, 2]),
    'zone_e': dict(bpm=116, root=67, scale='lydian', prog=[0, 4, 5, 2, 0, 4, 3, 1],
        bass=bass_pat('x... ..x. x... ..o.'), arp=[0, 1, 2, 3, 4, 3, 2, 1], arp_inst='bell', lead_shape='square',
        drums=dict(kick=pat('x... x... x... x...'), snare=pat('.... x... .... x...'), clap=pat('.... x... .... x...'), hat=[0, 1, 0, 1, 0, 1, 0, 1]),
        lead_rhythm=[4, 2, 2, 4, 4]),
    'zone_f': dict(bpm=90, root=47, scale='minor', prog=[0, 5, 3, 6, 0, 5, 2, 4], seventh=True,
        bass=bass_pat('x... .... x... ..o.'), arp=[0, None, 2, None, 4, None, 2, None], arp_inst='bell', lead_shape='saw',
        drums=dict(kick=pat('x... .... x... ....'), snare=pat('.... x... .... x...'), hat=[1, 0, 0, 1, 0, 1, 0, 0]),
        lead_rhythm=[6, 2, 4, 4], bars=32),
}

# ---------- sound effects ----------
def env_exp(n, k): return np.exp(-np.arange(n) / SR * k)

def sweep(f0, f1, n, shape='sine'):
    f = np.geomspace(f0, f1, n)
    return phase_osc(f, n, shape)

def sfx_click():
    n = int(0.06 * SR); return sweep(900, 1500, n) * env_exp(n, 60) * 0.7
def sfx_buy():
    out = np.zeros(int(0.7 * SR))
    for i, m in enumerate((72, 76, 79, 84)):
        n = int(0.35 * SR); s = (phase_osc(mtof(m), n, 'square') * 0.3 + phase_osc(mtof(m), n, 'sine')) * env_exp(n, 7)
        out[int(i * 0.07 * SR): int(i * 0.07 * SR) + n] += s[: len(out) - int(i * 0.07 * SR)][:n] if int(i*0.07*SR)+n <= len(out) else s[: len(out) - int(i * 0.07 * SR)]
    return out * 0.55
def sfx_deny():
    n = int(0.28 * SR); return (phase_osc(150, n, 'square') * 0.5 + phase_osc(143, n, 'saw') * 0.4) * env_exp(n, 9) * 0.7
def sfx_cash():
    n = int(0.3 * SR); return (inst_bell(mtof(88), n) + inst_bell(mtof(95), n) * 0.7) * 0.8
def sfx_coin():
    out = np.zeros(int(0.32 * SR))
    for i, m in enumerate((83, 88)):
        n = int(0.2 * SR); s = phase_osc(mtof(m), n, 'square') * env_exp(n, 14) * 0.45
        o = int(i * 0.075 * SR); out[o: o + n] += s[: len(out) - o][:n]
    return out
def sfx_checkpoint():
    out = np.zeros(int(0.9 * SR))
    for i, m in enumerate((67, 72, 76)):
        n = int(0.5 * SR); s = inst_bell(mtof(m + 12), n) * 0.7 + phase_osc(mtof(m), n, 'tri') * env_exp(n, 6) * 0.3
        o = int(i * 0.11 * SR); out[o: o + n] += s[: len(out) - o][:n]
    return out
def sfx_floor_clear():
    out = np.zeros(int(2.2 * SR))
    notes = [(60, 0.0), (64, 0.0), (67, 0.0), (72, 0.18), (76, 0.18), (79, 0.18), (84, 0.36), (88, 0.36), (91, 0.36), (96, 0.6)]
    for m, t0 in notes:
        n = int(1.2 * SR); s = phase_osc(mtof(m), n, 'saw') * 0.25 + phase_osc(mtof(m), n, 'square') * 0.15
        s = lowpass_seg(s, 5000) * adsr(n, 0.01, 0.2, 0.5, 0.5)
        o = int(t0 * SR); out[o: o + n] += s[: len(out) - o][:n]
    out += np.pad(inst_bell(mtof(96), int(1.5 * SR)), (int(0.6 * SR), 0))[: len(out)] * 0.5 if False else 0
    return out * 0.5
def sfx_death():
    n = int(0.7 * SR); s = sweep(500, 50, n, 'saw') * env_exp(n, 4); noise = fft_filter(rng_global.standard_normal(n), hi=1800) * env_exp(n, 7)
    return (s * 0.5 + noise * 0.5) * 0.8
def sfx_bounce():
    n = int(0.5 * SR); t = np.arange(n) / SR
    f = 220 * 2 ** (1.8 * (1 - np.exp(-t * 9))) * (1 + 0.03 * np.sin(2 * np.pi * 24 * t))
    return phase_osc(f, n, 'sine') * env_exp(n, 5) * 0.8
def sfx_speed():
    n = int(0.8 * SR); noise = fft_filter(rng_global.standard_normal(n), lo=800, hi=6000)
    env = np.sin(np.linspace(0, np.pi, n)) ** 1.5
    return (noise * env * 0.5 + sweep(300, 1800, n, 'saw') * env * 0.2)
def sfx_overdrive():
    n = int(2.6 * SR); s = sweep(60, 900, n, 'saw') * np.linspace(0.1, 1, n) ** 2 * 0.35
    boom = kick(int(0.9 * SR)) * 1.2
    out = s * env_exp(n, 0.8)
    o = int(1.7 * SR); out[o: o + len(boom)] += boom[: n - o][:len(boom)]
    for i, m in enumerate((60, 67, 72, 79, 84)):
        k = int(1.0 * SR); b = inst_bell(mtof(m + 12), k) * 0.5; o2 = int(1.7 * SR) + int(i * 0.05 * SR); out[o2: o2 + k] += b[: n - o2][:k]
    return out * 0.6
def sfx_unlock():
    out = np.zeros(int(1.0 * SR))
    for i, m in enumerate((72, 79, 84, 88, 91, 96)):
        n = int(0.5 * SR); s = inst_bell(mtof(m), n) * 0.7
        o = int(i * 0.06 * SR); out[o: o + n] += s[: len(out) - o][:n]
    return out * 0.7
def sfx_jump2():
    n = int(0.22 * SR); return sweep(380, 900, n, 'square') * env_exp(n, 14) * 0.35

SFX = dict(click=sfx_click, buy=sfx_buy, deny=sfx_deny, cash=sfx_cash, coin=sfx_coin, checkpoint=sfx_checkpoint, floor_clear=sfx_floor_clear,
           death=sfx_death, bounce=sfx_bounce, speed=sfx_speed, overdrive=sfx_overdrive, unlock=sfx_unlock, jump2=sfx_jump2)

def write_wav(path, data):
    a = np.clip(data, -1, 1)
    if a.ndim == 1: a = np.stack([a, a], axis=1)
    pcm = (a * 32767).astype('<i2')
    with wave.open(path, 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())

def encode(wav, ogg, q):
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', str(q), ogg], check=True)

if __name__ == '__main__':
    out = sys.argv[1]; os.makedirs(out, exist_ok=True)
    tmp = os.path.join(out, '_tmp'); os.makedirs(tmp, exist_ok=True)
    for i, (name, spec) in enumerate(TRACKS.items()):
        data = render_track(spec, 100 + i)
        wav = os.path.join(tmp, name + '.wav'); write_wav(wav, data)
        encode(wav, os.path.join(out, f'music_{name}.ogg'), 5)
        print(name, f'{len(data) / SR:.1f}s', 'peak %.2f rms %.3f' % (np.max(np.abs(data)), np.sqrt(np.mean(data ** 2))))
    for name, fn in SFX.items():
        s = fn().astype(float)
        s = s / (np.max(np.abs(s)) + 1e-9) * 0.9
        wav = os.path.join(tmp, name + '.wav'); write_wav(wav, s)
        encode(wav, os.path.join(out, f'sfx_{name}.ogg'), 6)
        print(name, f'{len(s) / SR:.2f}s')
    for f in os.listdir(tmp): os.remove(os.path.join(tmp, f))
    os.rmdir(tmp)
