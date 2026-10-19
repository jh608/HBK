# Test plan: compare the Simulink translations with PLECS

For a Claude Code session on a machine with PLECS installed. Read `CLAUDE.md` and
`README.md` first. Steps 1 and 2 of `CLAUDE.md` are done: all three Simulink models build,
compile, simulate in MATLAB R2024b and match the reference numbers from the Octave mock.
This plan covers the remaining check, which is to run the original `.plecs` models and the
Simulink models side by side.

## Goals

1. **Confirm the translation:** the same settings should give the same waveforms in PLECS
   and Simulink, within the tolerances below.
2. **Settle the README's open assumptions** ("Assumptions made where the PLECS file does not
   say", A1–A5 below).
3. **Gather facts for the owner's pending decisions** (D1–D4). Report them; don't make the
   decisions.
4. **Measure wall-clock times** in PLECS and Simulink for the same runs. Speed was the
   reason for the translation.

## Ground rules

* **Never edit the `.plecs` files in `plecs_source/`.**
  * Change settings in the GUI without saving, or with script calls on the loaded model.
  * If a modified copy is unavoidable, save it outside the repository.
* **A mismatch caused by the translation is a bug to fix.**
  * Fix it in the build script, plant file, params file or `simulink/common/p2s_*.m`,
    never in an `.slx`.
  * After a fix, rebuild, rerun `smoke_test`, and update the mock whitelist if needed (see
    `CLAUDE.md`).
* **A mismatch caused by a documented decision is not a bug.** Examples: the Class D leg
  inductance, the SRF-PLL, and the parts left out in the README.
  * Record the size of the difference instead.
* **Owner decisions (D1–D4): report, don't change the defaults.**
* **Don't commit large binaries** (waveform dumps, plots). Commit scripts and tables of
  numbers. Put bulky data in the session scratchpad, or under a git-ignored
  `validation/data/` if it must survive the session.
* **Commit each finished section** with the attribution trailers from `CLAUDE.md`.

## 0. Setup (do this first and report anything missing)

1. **Install check.**
   * Check that PLECS runs and its licence is valid. On the owner's development machine the
     installers were `plecs-standalone-4-9-4_win64.exe` and `plecs-blockset-4-9-5_win64.exe`.
   * Record the PLECS version.
   * Use PLECS **Standalone**: the `.plecs` files are Standalone models.
2. **Is MATLAB on this machine?**
   * **If yes:** do everything here.
   * **If no:**
     * export the PLECS waveforms as CSV to `validation/data/`;
     * commit only the scripts and a manifest (file name, run, settings, PLECS version);
     * leave a note in `CLAUDE.md` asking for the comparison to be finished on a MATLAB
       machine;
     * the PLECS-only checks (A1–A5, the speed figures, D2) can still be completed.
3. **Component library.**
   * The models use `plecs_source/Tiger  Library.plecs` (two spaces in the name).
   * Open each model and check that no library link is broken.
     * If one is, add `plecs_source/` to the PLECS library search path (Preferences).
     * Don't rename the file.
   * Note any missing device or thermal description files. They don't matter to the
     electrical comparison unless they also carry on-resistance or forward voltages
     (see 0.5).
4. **Scripting interface.**
   * Enable the RPC interface: PLECS Standalone *Preferences → General*, default port 1080.
   * Then drive PLECS from a script. Check the exact calls against the PLECS manual for the
     installed version (*Help → PLECS Manual*, chapter on simulation scripts / the RPC
     interface). From memory they are:
     * XML-RPC, which Python's standard library can call:
       `s = xmlrpc.client.Server('http://localhost:1080/RPC2')`, then `s.plecs.load(path)`,
       `s.plecs.simulate(model, {'ModelVars': {...}, 'SolverOpts': {...}})`,
       `s.plecs.get(path)` and `s.plecs.set(path, param, value)`.
     * JSON-RPC on the same port in recent versions, callable from MATLAB with `webwrite`.
       MATLAB has no built-in XML-RPC client.
     * `plecs.simulate` returns only the model's top-level output ports. These models
       mostly have scopes, so export scope data with `plecs.scope(<scope path>, 'ExportCSV',
       <file>)` after the run. Alternatively, add Signal Outports to an unsaved copy.
   * If the RPC route fails, fall back to the GUI: run the model, then use *File → Export*
     on the scope. Write down what you clicked so the run can be repeated.
   * Put the scripts in `tools/plecs_compare/` (new folder) and commit them.
5. **Make the PLECS models comparable.** Before any comparison, list for each model:
   * the solver: type, relative/absolute tolerance, max step;
   * every MOSFET or diode parameter that is not ideal: on-resistance, forward voltage,
     Coss and anything else electrical. The translation assumes zero on-resistance and zero
     forward voltage; Coss, snubbers and thermal effects are left out.

   For the comparison runs:
   * Set the PLECS relative tolerance to 1e-4, or match `RelTol` in Simulink: run
     `get_param(mdl, 'RelTol')` after building.
   * If the switches have non-zero on-resistance or forward voltage, run each case twice:
     as saved, and with those set to zero in the unsaved model. Only the zeroed run has to
     meet the tolerances.
   * Record what you changed.

## Getting the Simulink side

Build with `cd simulink; build_all`, or open the `.slx` files if they are committed.

**Overriding settings.** The models' InitFcn runs the params script, which overwrites
base-workspace variables. To override `sel_*` or gains for one run, append to the InitFcn of
the loaded, unsaved model:

```matlab
load_system(fullfile('simulink', 'classd', 'classd_revb.slx'));
set_param('classd_revb', 'InitFcn', [get_param('classd_revb', 'InitFcn') newline 'sel_ms = 2;']);
```

**Measurements.** Internal plant signals aren't top-level outputs. Log them from the outputs
of the `Memory (loop breaker)` block (the plant's measurement vector `y`) and of the
Integrator `x` (the state vector) in each power-stage subsystem:

```matlab
ph = get_param(blk, 'PortHandles');
set_param(ph.Outport(1), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'meas');
out = sim(mdl, 'StopTime', '4e-3', 'SignalLogging', 'on', 'SignalLoggingName', 'logsout');
v = out.logsout.getElement('meas').Values;   % Data may be 1x1xN or NxM: squeeze/transpose
```

The order of `y` is documented at the top of each `*_plant.m`. Top-level outputs are in
`out.yout`, in the order of the `outs` list near the end of each build script.

**Comparing.** Interpolate both runs onto a common time grid, or compare cycle-averaged
quantities. Simulink is variable-step, so the samples won't line up.

## Tolerances

Use these unless a case says otherwise. The aim is to tell a translation error apart from
solver and modelling differences.

* **Cycle-averaged or steady quantities:** within 2 %, or 2 V / 0.5 A, whichever is larger.
  This covers DC voltages, mean power, controller outputs and current amplitudes.
* **Switched waveforms** (bridge voltages, inductor currents over a few switching periods):
  * same shape;
  * edges within one dead time;
  * peak values within 5 %.
* **Transients** (start-up overshoots, PLL lock):
  * peak within 5 %;
  * timing within 10 %.
* **When a case fails:** overlay the two waveforms in a plot and narrow the cause before
  fixing. Plant, modulator, controller or measurement are the usual places. The open-loop
  cases (fixed φ or duty) exist to separate plant from controller.

## Test cases

Record PLECS and Simulink wall-clock times for every run (S1).

### DAB (`DAB FPGA.plecs` ↔ `dab_fpga`)

| id | settings | compare | notes |
|---|---|---|---|
| DAB-1 | as saved, 4 ms | Vo, Pin (input source power), φ, primary and secondary bridge voltages, i1 (Llk current), is | Simulink reference: φ saturates at 0.2450, Pin ≈ 2.98 kW, Vo 238.6 V at 4 ms |
| DAB-2 | open loop: hold φ constant at 0.15 and 0.30, 2 ms | same signals, the last 0.5 ms in detail | isolates plant + modulator from the PI. In Simulink set `dab_pid.up = dab_pid.lo = 2*phi` (the output is ×0.5). In PLECS do the equivalent on the PI limits or replace the PI output in an unsaved copy |
| DAB-3 | DAB-2 at φ = 0.30 with the transformer-internal leakages zeroed (Simulink `dab_tx.Lp = 0; dab_tx.Ls = 0;`; PLECS: same in the transformer block) | transferred power | for **D1**. Report power with and without the internal leakages in both tools |
| DAB-4 | `sel_alphaP = sel_alphaS = 2` (C-Script path), 4 ms | αP, αS, Vo | checks the C-Script translation |

DAB-1 also checks **A5 (load current direction):** positive power must flow to the load in
PLECS too.

### Class D (`Class D Rev B.plecs` ↔ `classd_revb`)

The PLECS file is saved with *No Inductors* (200 nH / 0.2 nH) and *No Filter*. For the
comparison, switch the PLECS "Class D Inductors" configuration to **No Mutual Inductance**
(75 µH per leg), the Simulink default.

| id | settings | compare | notes |
|---|---|---|---|
| CD-1 | `sel_ms = 2` (567.2 Hz sine × 10 A), 20 ms | load current amplitude and phase, Idemand, Vbus, the six leg currents | Simulink reference: 8.9 A amplitude for 10 A (89 %), bus 401.4 V, leg currents up to ±22 A |
| CD-2 | as saved: sine sweep (`sel_ms = 1`), 50 ms | load current against demand over the sweep | checks the sweep source (start/stop frequency, A4 units) |
| CD-3 | `sel_ipid = 2` (voltage-feedback PID path), `sel_ms = 2`, 20 ms | Vout, Iout | checks the second PID path and its anti-windup (A2) |
| CD-4 | **PLECS only**, as saved with the 200 nH / 0.2 nH inductors | does it run, how fast, the circulating current between legs | for **D2**. Then run Simulink with `Lleg = [200e-9; 0.2e-9*ones(5,1)]`: the expectation is that it stalls or circulates unbounded current |

### SixSwitch (`SixSwitch.plecs` ↔ `sixswitch`)

| id | settings | compare | notes |
|---|---|---|---|
| SS-1 | as saved (`sel_q = 1`), 25 ms | Vdc, grid currents, id/iq, PLL angle θ | Simulink reference: Vdc peaks at 984 V at 3.9 ms, 699 V at 17 ms; idq = [9.0, −60.4] A at 25 ms |
| SS-2 | `sel_q = 2` (q-axis PI connected), 25 ms | same | Simulink: Vdc 700.0–700.1 V, idq ≈ 0. For **D3** |
| SS-3 | `sel_q = 2`, 150 ms (covers the 100 W → 18 kW ramp from 50 ms) | Vdc regulation during the ramp, id, PI saturation (−32…40 A) | full-load behaviour; check the A2 anti-windup when the voltage PI saturates |
| SS-4 | `sel_load = 1` (440 Ω + pulsed 100 Ω loads), `sel_q = 2`, 100 ms | Vdc dips and recovery at each load pulse | second load option |
| SS-5 | SS-1 and SS-2, θ and the PLL frequency only | lock time, overshoot | for **D4**: the PLECS library PLL against the SRF-PLL (`pll.*`). Report the difference; if the owner wants a closer match, suggest a `pll.*` retune |

## Assumption checks (A1–A5)

Settle each from the PLECS documentation or block dialog first, then confirm with a run
where one is listed. Record the answer and its source: a manual section, the dialog text, or
a run id.

* **A1, manual switch position k selects input k** (upper input = 1).
  * In PLECS, toggle one switch (for example the DAB `Vout Target` / `Vout Ramp` switch).
    Note which input passes, and which value of the saved position parameter
    (`plecs.get`) that corresponds to.
  * Check one Manual Signal Switch and one Manual Switch: they may differ.
* **A2, PID anti-windup option 1 is back-calculation and option 3 is clamping.**
  * Read the PLECS PID Controller dialog and manual for `aw_method`.
  * Confirm with a saturating run: DAB-1, which saturates, then step `Vref` down. Compare
    how fast the PI comes off the limit in both tools.
* **A3, Periodic Average holds the last period's mean.**
  * Read the PLECS block manual.
  * Optionally feed a ramp through the block in an unsaved copy and compare with
    `p2s_periodic_avg`.
* **A4, PLECS sine sources use Hz and degrees.**
  * Read the Sine Wave block dialog: the units are printed next to the fields.
  * CD-2 / SS-1 phase alignment confirms it.
* **A5, the DAB load current source draws power from the output.** Checked in DAB-1.
* **Bonus: the SixSwitch filter inductor** is "saturable" in PLECS and linear in Simulink.
  * Check whether it saturates in SS-3.
  * If it does, report how much current it carries at saturation.

## Speed comparison (S1)

* Tabulate wall-clock time per run for PLECS and Simulink on this machine.
  * Simulink: run each model once first to warm the cache, then time `sim` with `tic/toc`.
  * PLECS: time the `plecs.simulate` call.
* Note any PLECS-side settings that change speed, such as the thermal network and scopes
  left open.
* **Results to beat from the owner's machine (R2024b):**
  * DAB 4 ms: 6.5 s;
  * Class D 20 ms: 5.7 s;
  * SixSwitch 25 ms: 3.5–3.7 s.
* If Simulink is not clearly faster, say so plainly. `CLAUDE.md` step 3.4 lists the
  speed-up options; offer them, but don't do them.

## Reporting

1. **README:** add a section "Comparison with PLECS". It holds:
   * the PLECS version and solver settings;
   * a table per model: case id, quantity, PLECS value, Simulink value, difference,
     pass/fail;
   * the speed table;
   * the A1–A5 answers with their sources.

   Edit the "Assumptions" section to mark each item confirmed or corrected.
2. **Wrong assumptions:** if one is wrong, fix the translation. For example, if position 1
   is the lower input, swap the `sel_*` meaning in the helper rather than the param values.
   Then rerun `smoke_test` and the affected cases, and update the reference numbers in
   `CLAUDE.md` and the README.
3. **CLAUDE.md:** update "Current state" and tick off step 3.2.
4. **Final message to the owner:**
   * pass/fail per model;
   * any translation bugs found and fixed;
   * the speed table;
   * the facts for D1–D4, each with the question the owner has to answer;
   * anything that couldn't be run, and why.

## Owner decisions this plan feeds (don't change these)

* **D1:** the DAB transformer leakage counted twice (DAB-3).
* **D2:** the Class D leg inductance: 75 µH or the saved 0.2 nH (CD-4).
* **D3:** whether to connect the SixSwitch q-axis PI (SS-1 against SS-2).
* **D4:** the SixSwitch PLL tuning (SS-5).
