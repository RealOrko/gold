# Gymnasium Migration Quick Checklist

Quick reference for migration progress. See [GYMNASIUM_MIGRATION_PLAN.md](./GYMNASIUM_MIGRATION_PLAN.md) for full details.

## Phase Status

- [x] **Phase 1:** Research & Planning (1 day) - COMPLETE
- [x] **Phase 2:** Sphere Backend (2-3 days) - COMPLETE
- [~] **Phase 3:** API Schema (2-3 days) - IN PROGRESS (Proto updated, bindings blocked)
- [ ] **Phase 3.5:** Protobuf Toolchain Modernization (1-2 days) - NEW
- [ ] **Phase 4:** Core Env Wrapper (1 day)
- [ ] **Phase 5:** Agent Updates (3-4 days)
- [ ] **Phase 6:** Integration Testing (2 days)
- [ ] **Phase 7:** Documentation (1 day)

**Total Progress:** 2.5/8 phases (31%)

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
- [~] Run `make generate` (blocked - see Phase 3.5)
- [ ] Update Gold vendor

### Protobuf Toolchain (Phase 3.5)
- [ ] Fix Dockerfile.gen base image (Debian Buster → Bullseye)
- [ ] Update Python 2 → Python 3 in toolchain
- [ ] Fix protoc-gen-go compatibility issues
- [ ] Update go_package option format
- [ ] Add googleapis proto dependencies
- [ ] Regenerate Go bindings successfully
- [ ] Regenerate Python bindings successfully
- [ ] Verify generated code compiles

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
| 3 | 2025-11-15 | 1.5h | API Proto Update | ~ Partial (proto updated, bindings blocked) |
| 3.5 | - | - | Toolchain Fix | Pending |
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
| Proto Bindings Strategy | Pending | Manual update vs toolchain fix (Phase 3.5) |
| Toolchain Modernization | ✓ Complete | Golang 1.19, Debian Bullseye, Python 3 |

---

## Blockers

### Active Blockers
- **Phase 3:** Protobuf generation toolchain broken
  - Old Dockerfile.gen uses deprecated Debian Buster (404 errors)
  - Python 2 no longer available in package repos
  - protoc-gen-go version incompatible with `go_package = "spherev1alpha"` format
  - Missing googleapis proto dependencies for google/api/annotations.proto
  - **Impact:** Cannot regenerate bindings; manual updates or toolchain fix required
  - **Workaround:** Proto source updated (committed); bindings pending Phase 3.5

---

## Next Session Goals

1. ~~Fork Sphere repository~~ ✓ Complete
2. ~~Update Python dependencies~~ ✓ Complete  
3. ~~Begin server.py modifications~~ ✓ Complete
4. ~~Update API protobuf schema~~ ✓ Complete (source)
5. **Fix protobuf toolchain** (Phase 3.5) - NEXT
6. Regenerate Go/Python bindings
7. Update Gold core env wrapper

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

*Last Updated: 2025-11-15*
