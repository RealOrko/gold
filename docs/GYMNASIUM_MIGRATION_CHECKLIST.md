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
- [ ] Update `Outcome` struct
- [ ] Update `InitialState` struct
- [ ] Update `Step()` method
- [ ] Update `Reset()` method

### Agents (Go)
- [ ] **DeepQ:** Fix bootstrapping logic
- [ ] **PPO:** Fix mask calculation
- [ ] **REINFORCE:** Update training loop
- [ ] **NES:** Update training loop
- [ ] **HER:** Update hindsight logic
- [ ] **Q:** Update training loop

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
| 4 | - | - | Core Wrapper | Pending |
| 5-7 | - | - | Agents | Pending |
| 8 | - | - | Testing | Pending |
| 9 | - | - | Docs | Pending |

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

*Last Updated: 2025-11-15*
