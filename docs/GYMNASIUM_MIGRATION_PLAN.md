# Gymnasium Migration Plan

**Project:** Gold RL Library
**Current Status:** Using OpenAI Gym via Sphere backend
**Target:** Upgrade to Gymnasium (v1.0.0+)
**Estimated Effort:** 12-17 days
**Last Updated:** 2025-11-15

---

## Executive Summary

This document outlines the complete migration path from OpenAI Gym to Gymnasium for the Gold reinforcement learning library. The migration touches three distinct layers:

1. **Sphere Backend** (Python) - The environment server
2. **Sphere API** (Protocol Buffers) - The gRPC interface 
3. **Gold Library** (Go) - The RL agent implementations

The most critical change is the **step API modification** from a single `done` boolean to separate `terminated` and `truncated` booleans, which is essential for correct reinforcement learning algorithm implementations.

---

## Table of Contents

1. [API Differences Reference](#api-differences-reference)
2. [Component Breakdown](#component-breakdown)
3. [Migration Phases](#migration-phases)
4. [Detailed Task List](#detailed-task-list)
5. [Testing Strategy](#testing-strategy)
6. [Rollback Plan](#rollback-plan)
7. [Session Progress Tracker](#session-progress-tracker)

---

## API Differences Reference

### Critical Changes

| Aspect | OpenAI Gym (Current) | Gymnasium (Target) | Impact Level |
|--------|---------------------|-------------------|--------------|
| **Step Return** | `obs, reward, done, info` | `obs, reward, terminated, truncated, info` | **CRITICAL** |
| **Reset Return** | `obs` | `obs, info` | **HIGH** |
| **Seeding** | `env.seed(42)` | `env.reset(seed=42)` | **MEDIUM** |
| **Render Mode** | `render(mode='human')` | Set in `make(render_mode='human')` | **MEDIUM** |
| **Package Name** | `import gym` | `import gymnasium` | **LOW** |

### Step API Semantic Difference

**This is THE most important change for RL correctness:**

```python
# OLD (Gym) - Ambiguous
obs, reward, done, info = env.step(action)
if done:
    next_value = 0  # Don't know if this is correct!

# NEW (Gymnasium) - Clear semantics  
obs, reward, terminated, truncated, info = env.step(action)
if terminated:
    # Episode ended naturally (success/failure)
    next_value = 0  # Correct - no future value
elif truncated:
    # Episode cut short (time limit)
    next_value = value_function(obs)  # Correct - estimate remaining value
```

**Why this matters:**
- `terminated`: Task succeeded/failed (goal reached, robot fell, etc.)
- `truncated`: External constraint (time limit, step limit, etc.)
- **Bootstrapping should only occur on truncation, not termination**
- Current Gold agents likely have subtle bugs due to not distinguishing these cases

### Reset API Changes

```python
# OLD
env.seed(42)
obs = env.reset()

# NEW
obs, info = env.reset(seed=42)
```

### Render Mode Changes

```python
# OLD - Dynamic switching
env = gym.make("CartPole-v1")
env.render(mode="human")
env.render(mode="rgb_array")

# NEW - Fixed at creation
env = gym.make("CartPole-v1", render_mode="human")
env.render()  # Uses the mode set at creation
```

---

## Component Breakdown

### 1. Sphere Docker Image (`sphereproject/gym`)

**Location:** External repo `github.com/aunum/sphere`
**Primary File:** `cmd/env/gym/server.py`

**Current Implementation:**
```python
# Uses gym
import gym
from gym import wrappers

# Step implementation
def StepEnv(self, request, context):
    env = self.envs[request.id]
    observation, reward, done, info = env.step(request.action)
    return StepEnvResponse(
        observation=encode_tensor(observation),
        reward=reward,
        done=done,
        info=s
    )
```

**Required Changes:**
- [ ] Update `requirements.txt` or `Dockerfile` to use `gymnasium` instead of `gym`
- [ ] Update all import statements
- [ ] Modify `StepEnv` to handle `terminated, truncated`
- [ ] Modify `ResetEnv` to handle `(obs, info)` return
- [ ] Update render mode handling in `CreateEnv`
- [ ] Update all wrapper imports (atari wrappers, etc.)
- [ ] Handle seeding in reset method

**Files to Modify:**
- `cmd/env/gym/server.py` (primary)
- `cmd/env/gym/Dockerfile` (dependencies)
- `cmd/env/gym/requirements.txt` (dependencies)
- `cmd/env/gym/baselines/baselines_ext/atari_wrapper.py` (wrappers)

**Estimated Effort:** 2-3 days

---

### 2. Sphere gRPC API (Protocol Buffers)

**Location:** External repo `github.com/aunum/sphere`
**Primary File:** `api/v1alpha/env.proto`

**Current Proto Definition:**
```protobuf
message StepEnvResponse {
    Tensor observation = 1;
    float reward = 2;
    bool done = 3;  // <-- This needs to split
    Tensor goal = 4;
    google.protobuf.Struct info = 5;
}
```

**Required Changes:**
```protobuf
message StepEnvResponse {
    Tensor observation = 1;
    float reward = 2;
    bool terminated = 3;  // NEW: Episode naturally ended
    bool truncated = 4;   // NEW: Episode hit external limit
    Tensor goal = 5;
    google.protobuf.Struct info = 6;
}

// Also update reset
message ResetEnvResponse {
    Tensor observation = 1;
    Tensor goal = 2;
    google.protobuf.Struct info = 3;  // NEW: Add info dict
}
```

**Breaking Change Considerations:**
- This is a **breaking API change**
- Existing Gold code will fail to compile
- Consider versioning: `v1alpha` → `v2alpha` or `v1beta`
- Could add compatibility layer (return both `done` and `terminated/truncated` temporarily)

**Files to Modify:**
- `api/v1alpha/env.proto`
- Regenerate all language bindings:
  - `api/gen/go/v1alpha/*.go`
  - `api/gen/python/v1alpha/*.py`

**Build Commands:**
```bash
# In sphere repo
make generate  # Regenerates protobuf bindings
```

**Estimated Effort:** 2-3 days (including testing)

---

### 3. Gold Library (Go Client)

**Location:** Current repo `/home/gavin/code/cryosharp/gold`

#### 3.1. Core Environment Wrapper

**File:** `pkg/v1/env/env.go`

**Current Implementation:**
```go
// Outcome of taking an action.
type Outcome struct {
    Observation *tensor.Dense
    Action int
    Reward float32
    Done bool  // <-- Needs to change
}

func (e *Env) Step(value int) (*Outcome, error) {
    resp, err := e.Client.StepEnv(...)
    return &Outcome{observation, value, resp.Reward, resp.Done}, nil
}
```

**Required Changes:**
```go
// Outcome of taking an action.
type Outcome struct {
    Observation *tensor.Dense
    Action int
    Reward float32
    Terminated bool  // NEW: Natural episode end
    Truncated bool   // NEW: External constraint end
}

func (e *Env) Step(value int) (*Outcome, error) {
    resp, err := e.Client.StepEnv(...)
    return &Outcome{
        Observation: observation,
        Action: value,
        Reward: resp.Reward,
        Terminated: resp.Terminated,
        Truncated: resp.Truncated,
    }, nil
}

// Helper method for backward compatibility during migration
func (o *Outcome) Done() bool {
    return o.Terminated || o.Truncated
}
```

**Also update:**
```go
type InitialState struct {
    Observation *tensor.Dense
    Goal *tensor.Dense
    Info map[string]interface{}  // NEW: Add info from reset
}

func (e *Env) Reset() (init *InitialState, err error) {
    resp, err := e.Client.ResetEnv(...)
    // Handle info from response
}
```

**Estimated Effort:** 1 day

---

#### 3.2. Agent Implementations

Each agent needs algorithm-specific updates to handle terminated vs truncated correctly.

##### Agent: Deep Q-Learning (`pkg/v1/agent/deepq/`)

**Files:**
- `agent.go` - Update learn logic
- `memory.go` - Update event storage
- `policy.go` - May need changes
- `experiments/cartpole/main.go` - Update training loop
- `experiments/pong/main.go` - Update training loop

**Current Code Pattern:**
```go
// experiments/cartpole/main.go
if outcome.Done {
    _, err = env.Reset()
    episodeCounter++
}
```

**Required Changes:**
```go
if outcome.Terminated || outcome.Truncated {
    _, err = env.Reset()
    episodeCounter++
}

// In learning/update logic - CRITICAL CHANGE:
// agent.go - Update target calculation
if event.Terminated {
    // No bootstrapping - episode naturally ended
    target = event.Reward
} else if event.Truncated {
    // Bootstrap from next state - episode cut short
    target = event.Reward + gamma * maxNextQ
} else {
    // Normal step - always bootstrap
    target = event.Reward + gamma * maxNextQ
}
```

**Memory Events:**
```go
// memory.go
type Event struct {
    State       *tensor.Dense
    Action      int
    Reward      float32
    Observation *tensor.Dense
    Terminated  bool  // NEW
    Truncated   bool  // NEW
}
```

**Estimated Effort:** 1.5 days

---

##### Agent: PPO (`pkg/v1/agent/ppo/`)

**Files:**
- `memory.go` - Update mask calculation
- `agent.go` - Update advantage calculation  
- `experiments/cartpole/main.go` - Update training loop

**Critical Change - Mask Calculation:**
```go
// memory.go - CURRENT (INCORRECT)
func (m *Memory) Track(outcome *envv1.Outcome, ...) {
    mask := float32(num.BoolToInt(!outcome.Done))  // WRONG
    // ...
}

// CORRECT VERSION
func (m *Memory) Track(outcome *envv1.Outcome, ...) {
    // Mask should be 0 only on TERMINATION, not truncation
    mask := float32(num.BoolToInt(!outcome.Terminated))
    // On truncation, we DO want to bootstrap!
    // ...
}
```

**Why this is critical:**
PPO uses masks for advantage calculation and value bootstrapping. Using `done` means it incorrectly zeros out the value when hitting time limits, which biases the policy.

**Estimated Effort:** 1.5 days

---

##### Agent: REINFORCE (`pkg/v1/agent/reinforce/`)

**Files:**
- `policy.go` - Update return calculation
- `experiments/cartpole/main.go` - Update training loop

**Required Changes:**
```go
// Less critical for REINFORCE since it uses Monte Carlo returns
// But should still distinguish for correctness
if outcome.Terminated || outcome.Truncated {
    _, err = env.Reset()
    // Calculate episode returns...
}
```

**Estimated Effort:** 0.5 days

---

##### Agent: NES (`pkg/v1/agent/nes/`)

**Files:**
- `blackbox.go` - Update fitness evaluation

**Required Changes:**
```go
// blackbox.go
if outcome.Terminated || outcome.Truncated {
    // Episode ended
}
```

**Note:** NES is less sensitive to terminated/truncated distinction since it's evolution-based, but should still be updated for consistency.

**Estimated Effort:** 0.5 days

---

##### Agent: HER (`pkg/v1/agent/her/`)

**Files:**
- `agent.go` - Update hindsight relabeling logic
- `memory.go` - Update event storage
- `experiments/bitflip/main.go` - Update training loop

**Critical for HER:**
```go
// agent.go - Hindsight relabeling
func (a *Agent) hindsightExperience(...) {
    // When relabeling, need to check if goal was achieved
    // vs. episode was truncated
    if event.Terminated && goalAchieved {
        event.Reward = 0.0  // Success
    }
}
```

**Estimated Effort:** 1 day

---

##### Agent: Q-Learning (`pkg/v1/agent/q/`)

**Files:**
- `experiments/taxi/main.go` - Update training loop

**Required Changes:**
```go
if outcome.Terminated || outcome.Truncated {
    _, err = env.Reset()
}

// In Q-value update (if applicable)
if outcome.Terminated {
    nextQ = 0
} else {
    nextQ = getMaxQ(nextState)
}
```

**Estimated Effort:** 0.5 days

---

### Summary of Agent Changes

| Agent | Files to Update | Complexity | Effort |
|-------|----------------|------------|--------|
| DeepQ | 5 files | High (bootstrapping logic) | 1.5 days |
| PPO | 3 files | High (mask calculation) | 1.5 days |
| REINFORCE | 2 files | Low | 0.5 days |
| NES | 1 file | Low | 0.5 days |
| HER | 3 files | Medium (hindsight logic) | 1 day |
| Q-Learning | 1 file | Low | 0.5 days |
| **Total** | **15 files** | - | **5.5 days** |

---

## Migration Phases

### Phase 1: Research & Planning ✓
**Duration:** 1 day
**Status:** COMPLETE

- [x] Analyze Gymnasium API differences
- [x] Document current codebase structure
- [x] Create migration plan document
- [x] Identify breaking changes

---

### Phase 2: Sphere Backend Update
**Duration:** 2-3 days
**Prerequisites:** None

**Tasks:**
1. Clone/fork Sphere repository
2. Create feature branch `gymnasium-migration`
3. Update dependencies to Gymnasium
4. Update `server.py` implementation
5. Update wrapper implementations
6. Test environment creation and interaction
7. Build new Docker image

**Deliverables:**
- [ ] Updated Sphere Docker image
- [ ] Passing environment tests
- [ ] Documentation of changes

**Testing:**
```bash
# Test CartPole
python test/cartpole/environment.py

# Test gym solver
python test/cartpole/gym_solver.py
```

---

### Phase 3: API Schema Update
**Duration:** 2-3 days
**Prerequisites:** Phase 2 complete

**Tasks:**
1. Update `env.proto` schema
2. Regenerate Go bindings
3. Regenerate Python bindings
4. Update API documentation
5. Consider versioning strategy
6. Test protobuf compilation

**Deliverables:**
- [ ] Updated proto files
- [ ] Regenerated bindings in all languages
- [ ] Updated API docs

**Commands:**
```bash
cd sphere/
make generate
# Verify generated files
ls api/gen/go/v1alpha/
ls api/gen/python/v1alpha/
```

---

### Phase 4: Gold Core Environment Wrapper
**Duration:** 1 day  
**Prerequisites:** Phase 3 complete

**Tasks:**
1. Update `Outcome` struct
2. Update `InitialState` struct
3. Update `Step()` method
4. Update `Reset()` method
4. Add backward compatibility helpers
5. Update tests

**Deliverables:**
- [ ] Updated `env.go`
- [ ] Passing unit tests

**Testing:**
```bash
cd pkg/v1/env/
go test -v
```

---

### Phase 5: Agent Updates (Parallel)
**Duration:** 3-4 days
**Prerequisites:** Phase 4 complete

Can be done in parallel or sequentially:

**5.1 Critical Agents (Sequential)**
1. DeepQ (1.5 days)
2. PPO (1.5 days)

**5.2 Simple Agents (Parallel)**
3. Q-Learning (0.5 days)
4. REINFORCE (0.5 days)
5. NES (0.5 days)

**5.3 Complex Agents**
6. HER (1 day)

**Deliverables:**
- [ ] Updated agent implementations
- [ ] Updated experiments
- [ ] Passing agent tests

---

### Phase 6: Integration Testing
**Duration:** 2 days
**Prerequisites:** Phase 5 complete

**Tasks:**
1. Test all agents with new API
2. Compare learning curves (before/after)
3. Verify reproducibility
4. Test Docker integration
5. Performance benchmarking

**Test Environments:**
- CartPole-v1
- Taxi-v3
- Pong (Atari)
- BitFlip (HER)

**Deliverables:**
- [ ] Test results documentation
- [ ] Performance comparison
- [ ] Bug fixes

---

### Phase 7: Documentation & Cleanup
**Duration:** 1 day
**Prerequisites:** Phase 6 complete

**Tasks:**
1. Update README.md
2. Update agent documentation
3. Create migration guide for users
4. Update examples
5. Code cleanup
6. Version tagging

**Deliverables:**
- [ ] Updated documentation
- [ ] Migration guide
- [ ] Clean commit history

---

## Detailed Task List

### Sphere Backend Tasks

- [ ] **SB-1:** Create Sphere fork/branch
- [ ] **SB-2:** Update `requirements.txt` to use `gymnasium>=1.0.0`
- [ ] **SB-3:** Update `Dockerfile` with gymnasium
- [ ] **SB-4:** Replace `import gym` with `import gymnasium as gym` in `server.py`
- [ ] **SB-5:** Update `StepEnv` to return terminated/truncated
- [ ] **SB-6:** Update `ResetEnv` to return info
- [ ] **SB-7:** Update `CreateEnv` to handle render_mode
- [ ] **SB-8:** Update atari wrapper imports
- [ ] **SB-9:** Test basic environment creation
- [ ] **SB-10:** Test step/reset cycles
- [ ] **SB-11:** Build Docker image `sphereproject/gymnasium:latest`
- [ ] **SB-12:** Push Docker image to registry

---

### API Schema Tasks

- [ ] **API-1:** Update `StepEnvResponse` proto message
- [ ] **API-2:** Update `ResetEnvResponse` proto message  
- [ ] **API-3:** Consider backward compatibility (v1 vs v2)
- [ ] **API-4:** Run `make generate` in Sphere repo
- [ ] **API-5:** Verify Go bindings generated correctly
- [ ] **API-6:** Verify Python bindings generated correctly
- [ ] **API-7:** Update Gold vendor dependencies
- [ ] **API-8:** Test proto compilation in Gold

---

### Gold Core Tasks

- [ ] **GC-1:** Update `Outcome` struct in `env.go`
- [ ] **GC-2:** Update `InitialState` struct in `env.go`
- [ ] **GC-3:** Update `Step()` method
- [ ] **GC-4:** Update `Reset()` method
- [ ] **GC-5:** Add `Done()` helper method to `Outcome`
- [ ] **GC-6:** Update `env_test.go`
- [ ] **GC-7:** Update server config for new image
- [ ] **GC-8:** Test compilation
- [ ] **GC-9:** Test basic environment interaction

---

### DeepQ Agent Tasks

- [ ] **DQ-1:** Update `Event` struct in `memory.go`
- [ ] **DQ-2:** Update `Track()` method in `memory.go`
- [ ] **DQ-3:** Update target calculation in `agent.go` (CRITICAL)
- [ ] **DQ-4:** Update experience replay logic
- [ ] **DQ-5:** Update `cartpole/main.go` training loop
- [ ] **DQ-6:** Update `pong/main.go` training loop
- [ ] **DQ-7:** Run CartPole experiment and verify learning
- [ ] **DQ-8:** Run Pong experiment and verify learning
- [ ] **DQ-9:** Update tests
- [ ] **DQ-10:** Document changes

---

### PPO Agent Tasks

- [ ] **PPO-1:** Update mask calculation in `memory.go` (CRITICAL)
- [ ] **PPO-2:** Update advantage calculation in `agent.go`
- [ ] **PPO-3:** Update `cartpole/main.go` training loop
- [ ] **PPO-4:** Run CartPole experiment and verify learning
- [ ] **PPO-5:** Update tests
- [ ] **PPO-6:** Document changes

---

### REINFORCE Agent Tasks

- [ ] **RF-1:** Update `cartpole/main.go` training loop
- [ ] **RF-2:** Update return calculation if needed
- [ ] **RF-3:** Run CartPole experiment
- [ ] **RF-4:** Update tests

---

### NES Agent Tasks

- [ ] **NES-1:** Update `blackbox.go` fitness evaluation
- [ ] **NES-2:** Update `cartpole/main.go` if present
- [ ] **NES-3:** Run experiment
- [ ] **NES-4:** Update tests

---

### HER Agent Tasks

- [ ] **HER-1:** Update `Event` struct in `memory.go`
- [ ] **HER-2:** Update hindsight relabeling in `agent.go`
- [ ] **HER-3:** Update `bitflip/main.go` training loop
- [ ] **HER-4:** Run BitFlip experiment
- [ ] **HER-5:** Verify goal achievement detection
- [ ] **HER-6:** Update tests

---

### Q-Learning Agent Tasks

- [ ] **Q-1:** Update `taxi/main.go` training loop
- [ ] **Q-2:** Update Q-value calculation if needed
- [ ] **Q-3:** Run Taxi experiment
- [ ] **Q-4:** Update tests

---

## Testing Strategy

### Unit Tests

**Environment Tests:**
```bash
cd pkg/v1/env/
go test -v -run TestStep
go test -v -run TestReset
```

**Agent Tests:**
```bash
cd pkg/v1/agent/deepq/
go test -v
cd pkg/v1/agent/ppo/
go test -v
# etc...
```

---

### Integration Tests

**Environment Connection:**
```bash
# Test Sphere server connection
cd pkg/v1/env/
go test -v -run TestServer
```

**Agent Training:**
```bash
# Run short training sessions
cd pkg/v1/agent/deepq/experiments/cartpole/
go run main.go  # Should solve in ~100 episodes
```

---

### Regression Tests

**Learning Curves:**
- Compare episode rewards before/after migration
- Verify similar convergence rates
- Check for performance degradation

**Reproducibility:**
```bash
# Run same experiment with same seed multiple times
# Results should be identical
go run main.go --seed 42
go run main.go --seed 42  # Should match first run
```

---

### Performance Benchmarks

```bash
# Measure step throughput
go test -bench=BenchmarkStep

# Measure episode completion time
time go run experiments/cartpole/main.go
```

---

## Rollback Plan

If issues arise during migration:

### Stage 1: Sphere Backend Issues
**Rollback:** Use old Docker image
```bash
# In server.go
var GymServerConfig = &LocalServerConfig{
    Image: "sphereproject/gym",
    Version: "v0.21",  // Old version
}
```

### Stage 2: API Issues
**Rollback:** Revert proto changes, regenerate bindings
```bash
cd sphere/
git revert <commit-hash>
make generate
```

### Stage 3: Agent Issues
**Rollback:** Keep old branch, cherry-pick working agents
```bash
git checkout main
git checkout -b gymnasium-migration-partial
git cherry-pick <working-agent-commits>
```

---

## Session Progress Tracker

### Session 1: 2025-11-15
**Duration:** ~1 hour
**Focus:** Research and planning

**Completed:**
- [x] Analyzed Gymnasium API
- [x] Reviewed current codebase
- [x] Created migration plan document
- [x] Documented all required changes

**Next Session:**
- [ ] Begin Sphere backend updates
- [ ] Fork Sphere repository
- [ ] Update Python dependencies

---

### Session 2: [Date]
**Duration:** TBD
**Focus:** TBD

**Planned:**
- [ ] Task here

**Completed:**
- [ ] Task here

**Blockers:**
- None

---

### Session 3: [Date]
**Duration:** TBD
**Focus:** TBD

---

## Key Decision Points

### Decision 1: API Versioning Strategy

**Options:**
1. **Breaking change in v1alpha** (faster, simpler)
2. **Create v2alpha** (cleaner, but more overhead)
3. **Add compatibility fields** (maintain both `done` and `terminated/truncated` temporarily)

**Recommendation:** Option 1 - This is alpha software, breaking changes are expected

**Status:** PENDING

---

### Decision 2: Docker Image Naming

**Options:**
1. **New image:** `sphereproject/gymnasium:latest`
2. **Same image:** `sphereproject/gym:v2`
3. **Tag-based:** `sphereproject/gym:gymnasium`

**Recommendation:** Option 1 - Clear distinction between Gym and Gymnasium

**Status:** PENDING

---

### Decision 3: Sphere Repository Strategy

**Options:**
1. **Fork and modify** - Create fork, maintain separately
2. **Pull request to upstream** - Contribute back
3. **Vendored copy** - Include in Gold repo

**Recommendation:** Option 2 - Contribute back to benefit community

**Status:** PENDING

---

## Resources

### Documentation
- [Gymnasium API Docs](https://gymnasium.farama.org/api/env/)
- [Migration Guide](https://gymnasium.farama.org/introduction/migration_guide/)
- [Sphere Repository](https://github.com/aunum/sphere)
- [Gold Repository](https://github.com/aunum/gold)

### Key Papers
- [Gymnasium Paper](https://arxiv.org/abs/2407.17032)
- [Terminated/Truncated Blog](https://farama.org/Gymnasium-Terminated-Truncated-Step-API)

### Community
- [Gymnasium Discord](https://discord.gg/bnJ6kubTg6)
- [GitHub Issues](https://github.com/Farama-Foundation/Gymnasium/issues)

---

## Notes

### Important Considerations

1. **RL Algorithm Correctness:** The terminated/truncated distinction is NOT just cosmetic - it directly affects value bootstrapping and is critical for correct RL implementations.

2. **Time Limit Handling:** Most environments use `TimeLimit` wrapper which previously set `info['TimeLimit.truncated']`. This is now handled by the `truncated` return value.

3. **Render Mode:** Cannot switch dynamically anymore - must be set at environment creation. May need separate env instances for training (no render) and evaluation (render).

4. **Backward Compatibility:** Consider maintaining a compatibility layer during transition, especially if Gold is used by external projects.

5. **Testing Thoroughness:** Each agent's learning behavior should be validated - not just "does it compile" but "does it learn correctly."

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Sphere repo changes break existing functionality | Medium | High | Comprehensive testing, maintain old Docker image |
| Proto changes break other clients | Low | Medium | Clear versioning, migration guide |
| Agent learning degrades | Low | High | Regression testing, learning curve comparison |
| Performance degradation | Low | Medium | Benchmarking before/after |
| Docker image compatibility issues | Medium | Medium | Test on multiple platforms |
| Dependency conflicts | Low | Low | Pin versions carefully |

---

## Success Criteria

Migration is considered successful when:

- [ ] All agents compile without errors
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] CartPole experiment solves in similar time
- [ ] Pong experiment shows learning
- [ ] Learning curves match pre-migration performance
- [ ] Docker image builds and runs successfully
- [ ] Documentation is complete and accurate
- [ ] Code review passed
- [ ] No performance regressions

---

## Future Enhancements (Post-Migration)

Once migration is complete, consider:

1. **Add new Gymnasium environments** (MuJoCo v5, etc.)
2. **Leverage new wrappers** (Gymnasium has improved wrapper ecosystem)
3. **Improve error handling** with better info dicts
4. **Add type hints** using Gymnasium's improved typing
5. **Vector environments** - Gymnasium has better vectorization support

---

*This is a living document. Update as progress is made and new information is discovered.*
