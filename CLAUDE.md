# HBK — PLECS → Simulink translations: guide for Claude Code sessions

Read `README.md` first: it describes the three models, the mapping from the PLECS blocks,
what was left out, the assumptions made and the issues found in the PLECS models. This file
covers how to carry the work on, especially in a local session that has MATLAB.

## Goal

Three PLECS models (`plecs_source/`) have been translated into plain Simulink (no Simscape),
with ideal switches, so the owner can evaluate the control strategies faster than in PLECS:

| model | build script | plant equations | parameters (the model's InitFcn runs this) |
|---|---|---|---|
| DAB | `simulink/dab/dab_build.m` | `dab_plant.m` | `dab_params.m` |
| Class D | `simulink/classd/classd_build.m` | `classd_plant.m` | `classd_params.m` |
| SixSwitch | `simulink/sixswitch/sixswitch_build.m` | `sixswitch_plant.m` | `sixswitch_params.m` |

## Current state (as of 2026-10-19), read before doing anything

* The work so far was done in a cloud session **without MATLAB**. The build scripts were run
  against `tools/mock_simulink/`, an Octave stand-in for the Simulink API. It checks block
  paths, parameter names, enum values and wiring, and simulates the block graph with a fixed
  step. The plant `.m` files run unchanged in Octave.
* **Steps 1 and 2 are done (2026-10-19, local session, MATLAB R2024b).** All three models
  build, compile and simulate, and the results match the reference numbers below. The
  figures and wall-clock times are in the README ("Runs in MATLAB R2024b"). Two MATLAB-only
  fixes were needed:
  * the Selector blocks were replaced with Gain matrices (`26d8ad5`);
  * the DAB plant's input sizes are declared (`p2s_mfun`'s `sizes` argument), because the
    gate loop defeats dimension propagation.
* What remains is step 3: the PLECS comparison and the owner's decisions. PLECS is not
  installed on the owner's development machine. The comparison is planned in
  `PLECS_TEST_PLAN.md`, for a session on a machine that has PLECS.

## Step 1: build and smoke-test in MATLAB

From the repository root:

```sh
matlab -batch "cd simulink; smoke_test"            # all three models
matlab -batch "cd simulink; smoke_test('classd')"  # one model: dab | classd | sixswitch
```

For each model, `simulink/smoke_test.m`:

1. runs the build script;
2. compiles the model (`SimulationCommand update`);
3. simulates a short window;
4. prints the final value of the first top-level outputs, or the stage, message and stack
   of the first error.

`build_all.m` only builds. The `.slx` files are written next to each `*_params.m` and are
generated artefacts: regenerate them, never hand-edit them. Whether to commit them is the
owner's call. Committing would let them open the models without building.

When something fails:

* **Fix the build script or the helper in `simulink/common/p2s_*.m`, never the `.slx`.**
* If MATLAB rejects a parameter name or value, look it up for the installed release
  (`get_param(blk, 'ObjectParameters')`, `get_param(blk, 'DialogParameters')`, or the
  block's documentation). Then fix the script, and also the parameter whitelist in
  `tools/mock_simulink/mock_libtable.m` so the mock stays faithful (the mock is still useful
  for the cloud sessions, which have no MATLAB).
* Re-run `smoke_test` until all three build, compile and simulate.

### Places most likely to break in real MATLAB (written from memory, never executed)

These are listed roughly by risk.

* **`p2s_mfun.m`: MATLAB Function blocks.** It sets the code with
  `sfroot().find('-isa','Stateflow.EMChart','Path',p).Script = code`. It then turns the last
  argument into a workspace parameter with `chart.find('-isa','Stateflow.Data','Name',n).Scope = 'Parameter'`.
  The parameter structs are `Pdab`, `Pcd` and `Pss`, created by the params scripts.
* **Data types:**
  * Relational and Logical operators output `boolean`. These are muxed and fed straight into
    the MATLAB Function blocks, which cast with `double()`.
  * Relational outputs also drive `Switch` control ports.
  * If MATLAB complains about boolean versus double, add Data Type Conversion blocks; don't
    change the plant code.
* **PID blocks (`p2s_pid.m`).** Parameter names used: `Controller`, `Form`, `P`, `I`,
  `InitialConditionForIntegrator`, `LimitOutput`, `UpperSaturationLimit`,
  `LowerSaturationLimit`, `AntiWindupMode` (`back-calculation` / `clamping`), `Kb`,
  `SampleTime`, `IntegratorMethod` (`Forward Euler`).
* **Memory block** `InitialCondition`. **Unit Delay** `InitialCondition`, `SampleTime`.
  **Transport Delay** `DelayTime`, `InitialOutput`, `BufferSize`.
* **Fcn blocks:** `Expr` that uses `rem`, `abs`, `sin`, relational operators and workspace
  variables. `pi` is avoided on purpose: the code writes `6.283185307179586` or `2*pi` only
  in block parameters, not inside Fcn expressions.
* **Model configuration (`p2s_new_model.m`):**
  * solver `ode23tb`, `ZeroCrossAlgorithm` `Adaptive`, `MaxConsecutiveZCsMsg` `none`;
  * `SaveFormat` `Dataset`;
  * an `InitFcn` that `addpath`s the model folder and runs the params script.
* **`p2s_arrange.m`** calls `Simulink.BlockDiagram.arrangeSystem` inside `try`. A layout
  failure is harmless but leaves an ugly diagram.

## Step 2: check the results against the reference numbers

These come from the Octave mock (fixed step 4–100 ns, forward Euler), so Simulink's
variable-step results should be close, not identical:

* **DAB, 4 ms:**
  * bridge voltages ±700 V and ±250 V;
  * the secondary voltage has a 5 % zero state (αS = 0.025);
  * the PI saturates at φ = 0.245, delivering ≈ 2.5–3 kW;
  * Vo sags 250 → 238 V.

  The sag is the real behaviour of the circuit as saved, because the transformer leakage is
  counted twice (see the README). It is not a translation bug.
* **Class D:** with `sel_ms = 2` (567.2 Hz sine × 10 A demand) the load current follows at
  ≈ 85 % amplitude, and the bus settles at 401 V. Leg currents carry ≈ ±25 A of circulating
  ripple: 75 µH uncoupled, interleaved legs.
* **SixSwitch:**
  * as saved (`sel_q = 1`, q-axis PI bypassed by −1.85 V): Vdc peaks at ≈ 965 V around 4 ms
    while the PLL locks, then settles at ≈ 700 V by 17 ms; iq drifts to ≈ −60 A by 25 ms;
  * with `sel_q = 2`: Vdc stays at 700 ± 1.5 V and the currents are ≈ 0 at the 100 W
    initial load.

If PLECS is installed, the strongest check is to run the original `.plecs` model and the
Simulink model side by side and compare waveforms. That also resolves the open assumptions
below.

## Step 3: open items, in rough priority

1. Get the three models building and simulating in MATLAB (above), then report the
   wall-clock simulation times to the owner. Speed was the reason for the translation.
2. **Confirm the assumptions** listed in the README (ideally against PLECS):
   * manual switch position k selects input k;
   * PLECS PID anti-windup option 1 is back-calculation and option 3 is clamping;
   * Periodic Average holds the last period's mean;
   * the sine phase units are degrees;
   * the DAB load current direction.
3. **Owner decisions pending — ask, don't change:**
   * the double-counted DAB leakage (`dab_tx.Lp/Ls`);
   * the Class D leg inductance: the default is 75 µH; the PLECS file was saved with
     0.2 nH;
   * whether the SixSwitch q-axis PI should be connected (`sel_q`);
   * the SixSwitch PLL tuning (`pll.*`): the PLECS library PLL was replaced by an SRF-PLL.
4. **Possible speed-ups if the owner wants more** (not done; ask first):
   * a switching-cycle averaged variant of each plant (leg voltage = duty × Vdc);
   * a tighter `MaxStep`/`RelTol` study;
   * Accelerator mode.
5. **Not translated:**
   * the DAB "Triple Phase Shift Modulator" (an unused alternative path);
   * THD meters;
   * the thermal, loss and small-signal analysis blocks;
   * the two filter-analysis test benches (`Current Feedback Filter`,
     `SixSwitch Filter Testing`);
   * the PLECS scripts.

## Working rules

* The power stage of each model is the `*_plant.m` file, embedded at build time
  (`fileread`). To change circuit equations, edit the plant file and rebuild.
  * The plant files must stay MATLAB-Function (codegen) compatible.
  * The last argument is the parameter struct.
  * Measurements pass through a Memory block (an algebraic-loop breaker), initialised from
    `*_y0`, which the params script computes by calling the plant once.
* Gate edges must come from Relational Operators on continuous signals, so zero-crossing
  detection locates them; never from logic inside the MATLAB Function. The diode-direction
  inputs come from the integrator states for the same reason.
* Switch positions and controller gains live in the `*_params.m` files (`sel_*`, `ipid.*`,
  `cc.*`, `vc.*`, `pll.*`, …), not in block dialogs.
* **Never put `tools/mock_simulink` on the MATLAB path.** It shadows `add_block`,
  `set_param` and other built-ins; its functions error out under MATLAB on purpose. The
  mock is for cloud sessions without MATLAB: `cd tools/mock_simulink; octave-cli --eval
  "run_build_check('dab')"`, plus `selftest` and `sim_check_dab`.
* Git: work on `main` (the only branch). Commit messages end with the Claude Code attribution
  trailers. Don't push binaries other than the `.slx` models, and push those only if the
  owner wants them committed.
