# Gymnasium Migration Quick Checklist

Quick reference for migration progress. See [GYMNASIUM_MIGRATION_PLAN.md](./GYMNASIUM_MIGRATION_PLAN.md) for full details.

## Phase Status

- [x] **Phase 1:** Research & Planning (1 day) - COMPLETE
- [x] **Phase 2:** Sphere Backend (2-3 days) - COMPLETE
- [x] **Phase 3:** API Schema (2-3 days) - COMPLETE
- [x] **Phase 3.5:** Protobuf Toolchain Modernization (1-2 days) - COMPLETE
- [ ] **Phase 4:** Core Env Wrapper (1 day)
- [ ] **Phase 5:** Agent Updates (3-4 days)
- [ ] **Phase 6:** Integration Testing (2 days)
- [ ] **Phase 7:** Documentation (1 day)

**Total Progress:** 4/8 phases (50%)

---

## Critical API Changes to Implement

### 1. Step API ⚠️ MOST IMPORTANT
```diff
- obs, reward, done, info = env.step(action)
+ obs, reward, terminated, truncated, info = env.step(action)
```

### 2. Reset API
```diff
- obs = env.reset()
+ obs, info = env.reset(seed=42)
```

### 3. Render Mode
```diff
- env.render(mode='human')
+ env = gym.make(..., render_mode='human')
+ env.render()
```

---

## Quick Task List

### Sphere (Python)
- [x] Update to `gymnasium>=1.0.0` (using 0.28.1 for Python 3.7 compatibility)
- [x] Change imports: `import gymnasium as gym`
- [x] Update `StepEnv()` return values
- [x] Update `ResetEnv()` return values
- [x] Build new Docker image (realorko/sphere-gymnasium:latest)

### API (Protobuf)
- [x] Add `terminated` field to `StepEnvResponse`
- [x] Add `truncated` field to `StepEnvResponse`
- [x] Add `info` field to `ResetEnvResponse`
- [x] Run `make generate`
- [x] Update Gold vendor

### Protobuf Toolchain (Phase 3.5)
- [x] Fix Dockerfile.gen base image (Debian Buster → Bullseye)
- [x] Update Python 2 → Python 3 in toolchain
- [x] Fix protoc-gen-go compatibility issues
- [x] Update go_package option format
- [x] Add googleapis proto dependencies
- [x] Regenerate Go bindings successfully
- [x] Regenerate Python bindings successfully
- [x] Verify generated code compiles

### Gold Core (Go)
- [ ] Update `Outcome` struct (BREAKING: remove Done, add Terminated/Truncated/Info)
- [ ] Update `InitialState` struct (add Info field)
- [ ] Update `Step()` method (return Terminated/Truncated from response)
- [ ] Update `Reset()` method (return Info from response)

### Agents (Go) - ALL MUST UPDATE SIMULTANEOUSLY
- [ ] **DeepQ:** Fix bootstrapping logic (`!event.Done` → `!event.Terminated`)
- [ ] **PPO:** Fix mask calculation (`!outcome.Done` → `!outcome.Terminated`)
- [ ] **HER:** Fix hindsight logic (`event.Done = true` → `event.Terminated = true`)
- [ ] **REINFORCE:** Update episode detection (`outcome.Done` → `outcome.Terminated || outcome.Truncated`)
- [ ] **NES:** Update episode detection (`outcome.Done` → `outcome.Terminated || outcome.Truncated`)
- [ ] **Q:** Update episode detection (`outcome.Done` → `outcome.Terminated || outcome.Truncated`)
- [ ] **All Experiments:** Update loop termination (6 files total)

---

## Testing Checklist

- [ ] Sphere server starts successfully
- [ ] CartPole environment creates
- [ ] Step returns correct values
- [ ] Reset returns correct values
- [ ] DeepQ agent learns CartPole
- [ ] PPO agent learns CartPole
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Learning curves match baseline

---

## Session Log

| Session | Date | Duration | Tasks | Status |
|---------|------|----------|-------|--------|
| 1 | 2025-11-15 | 1h | Research & Planning | ✓ Complete |
| 2 | 2025-11-15 | 2h | Sphere Backend | ✓ Complete |
| 3 | 2025-11-15 | 1.5h | API Proto Update | ✓ Complete |
| 3.5 | 2025-11-15 | 2h | Toolchain Modernization | ✓ Complete |
| 4 | 2025-11-15 | 1h | Phase 4/5 Planning & Analysis | ✓ Complete |
| 5 | - | - | Core Wrapper Implementation | Pending Approval |
| 6 | - | - | Agent Updates | Pending |
| 7 | - | - | Testing | Pending |
| 8 | - | - | Docs | Pending |

---

## Decision Tracker

| Decision | Status | Choice |
|----------|--------|--------|
| API Versioning | ✓ Complete | Keep v1alpha, breaking change acceptable |
| Docker Image Name | ✓ Complete | realorko/sphere-gymnasium:latest |
| Sphere Repo Strategy | ✓ Complete | Forked to RealOrko/sphere, branch: gymnasium-migration |
| Gymnasium Version | ✓ Complete | 0.28.1 (Python 3.7 compatible) |
| Backward Compatibility | ✓ Complete | Combined terminated\|truncated into done (Python) |
| Proto Bindings Strategy | ✓ Complete | Toolchain fix successful (Phase 3.5) |
| Toolchain Modernization | ✓ Complete | Golang 1.19, Debian Bullseye, Python 3, grpc-gateway v1.16 |
| Gold API Strategy | ✓ Complete | Full Gymnasium alignment - remove Done, use Terminated/Truncated |

---

## Blockers

### Active Blockers
- None - Phase 3.5 successfully resolved all toolchain blockers!

---

## Next Session Goals

1. ~~Fork Sphere repository~~ ✓ Complete
2. ~~Update Python dependencies~~ ✓ Complete  
3. ~~Begin server.py modifications~~ ✓ Complete
4. ~~Update API protobuf schema~~ ✓ Complete
5. ~~Fix protobuf toolchain~~ ✓ Complete (Phase 3.5)
6. ~~Regenerate Go/Python bindings~~ ✓ Complete
7. **Update Gold core env wrapper** - NEXT (Phase 4)

---

## Session 3 Summary (2025-11-15)

### Completed
- ✅ Updated `env.proto` with `terminated`/`truncated` fields in StepEnvResponse
- ✅ Added `info` field to ResetEnvResponse  
- ✅ Updated Dockerfile.gen to Golang 1.19 + Debian Bullseye + Python 3
- ✅ Committed proto schema changes to sphere repo

### Discovered Issues
- ⚠️ Sphere protobuf toolchain is outdated and broken:
  - Debian Buster repos archived (404 errors)
  - Python 2 packages unavailable
  - protoc-gen-go incompatible with old `go_package` format
  - Missing googleapis dependencies

### Decisions Made
- Keep API at v1alpha (breaking change acceptable for private API)
- Phase 3.5 added for toolchain modernization
- Proto source is updated and committed (source of truth)
- Bindings regeneration deferred to Phase 3.5

---

## Session 4 Summary (2025-11-15) - Phase 3.5

### Completed
- ✅ Fixed Dockerfile.gen with modern toolchain:
  - Golang 1.19 on Debian Bullseye
  - Python 3 with pip3
  - grpc-gateway v1.16.0 (go install with proper modules)
  - googleapis cloned for proto dependencies
- ✅ Updated `go_package` options in proto files for protoc-gen-go v1.5.2 compatibility
- ✅ Updated prototool.yaml to use /googleapis path
- ✅ Regenerated Go bindings with terminated/truncated fields
- ✅ Regenerated Python bindings with gymnasium fields
- ✅ Updated Gold vendor with new sphere bindings
- ✅ Verified Gold compiles successfully with new bindings
- ✅ Improved Makefile with automated generation workflow

### Key Technical Details
- Used `go install` with version tags instead of deprecated `go get`
- Added `paths=source_relative` flag to control output directory structure
- Cloned googleapis directly instead of relying on grpc-gateway's third_party copy
- Handled Docker container permission issues with sudo chown

### Phase 3.5 Results
- **Status:** ✅ COMPLETE
- **Duration:** 2 hours
- **Impact:** Unblocked Phase 3, modernized toolchain for future maintainability
- **Commits:** 
  - sphere: b308488 "Phase 3.5: Modernize protobuf toolchain"
  - gold: 19dbcce "Update sphere API bindings with gymnasium fields"

---

## Session 5 Summary (2025-11-15) - Phase 4 Planning

### Code Analysis Completed
- ✅ Analyzed all agent implementations for `Done` field usage
- ✅ Identified critical RL semantic issues:
  - **DeepQ bootstrapping** (agent.go:138): Uses `!event.Done` for Q-learning target calculation
  - **PPO value mask** (memory.go:27): Uses `!outcome.Done` for value function continuity
  - **HER hindsight** (agent.go:253): Manually sets `event.Done = true` for achieved goals
- ✅ Found 18 references to `.Done` across 6 agents + experiments
- ✅ Confirmed Event structs embed `*envv1.Outcome` (affects all agents)

### Architecture Discovery
**Event struct pattern (DeepQ, HER, PPO):**
```go
type Event struct {
    *envv1.Outcome  // Embeds Done field
    State *tensor.Dense
    // ... other fields
}
```

**Critical usage patterns:**
1. **Bootstrapping** (DeepQ line 138, HER line 141): `if !event.Done` → Must become `!event.Terminated`
2. **Value masks** (PPO line 27): `!outcome.Done` → Must become `!outcome.Terminated`
3. **Episode detection** (all experiments): `if outcome.Done` → Must become `outcome.Terminated || outcome.Truncated`
4. **Hindsight goals** (HER line 253): `event.Done = true` → Must become `event.Terminated = true`

### Decision: Full Gymnasium Alignment
**Rationale:**
- Correct RL semantics require distinguishing termination types
- Bootstrapping on truncated episodes is mathematically incorrect
- No benefit to maintaining backward compatibility layer
- Clean break better than technical debt

**Breaking Changes:**
- Remove `Done bool` from `Outcome` struct
- Add `Terminated bool`, `Truncated bool`, `Info *_struct.Struct` to `Outcome`
- Add `Info *_struct.Struct` to `InitialState`
- All agents must update simultaneously

### Impact Assessment
| Component | Files | Critical Changes | Risk Level |
|-----------|-------|------------------|------------|
| Core Env | 1 | Outcome/InitialState structs + Step/Reset methods | HIGH |
| DeepQ | 2 | Bootstrapping logic (`!Done` → `!Terminated`) | CRITICAL |
| PPO | 2 | Mask calculation (`!Done` → `!Terminated`) | CRITICAL |
| HER | 2 | Hindsight + bootstrapping | CRITICAL |
| REINFORCE | 1 | Episode detection only | LOW |
| NES | 1 | Episode detection only | LOW |
| Q | 1 | Episode detection only | LOW |
| Experiments | 6 | Loop termination | LOW |
| **TOTAL** | **16** | **23 code locations** | **HIGH** |

### Implementation Plan Approved
**Phase 4: Core Wrapper (BREAKING)**
1. Update `Outcome` struct: Remove `Done`, add `Terminated`/`Truncated`/`Info`
2. Update `InitialState` struct: Add `Info`
3. Update `Step()` method: Use `resp.Terminated`/`resp.Truncated`
4. Update `Reset()` method: Use `resp.Info`

**Phase 5: Agent Updates (MUST BE SIMULTANEOUS)**
1. Fix experiments (episode detection): `Done` → `Terminated || Truncated`
2. Fix REINFORCE/NES/Q (simple algorithms)
3. Fix PPO (mask calculation): `!Done` → `!Terminated`
4. Fix DeepQ (bootstrapping): `!Done` → `!Terminated`
5. Fix HER (most complex): hindsight + bootstrapping

**Phase 6: Testing**
1. Unit tests for env package
2. Integration tests with CartPole (DeepQ, PPO)
3. Verify learning curves

### Next Session Goals
1. **Await approval to proceed with breaking changes**
2. Update core `Outcome`/`InitialState` structs
3. Update `Step()`/`Reset()` methods
4. Begin agent updates (experiments first, then agents by complexity)

---

*Last Updated: 2025-11-15 (Session 5)*
