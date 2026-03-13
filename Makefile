# Saturn Workspace - Global Makefile
# Pure dispatch — all logic lives in scripts/

WORKSPACE := $(shell pwd)
SERVICES  := mars shuttle chat jupiter saturn-backend saturn-fe abe area51
SCRIPTS   := $(addprefix scripts/,$(addsuffix .sh,$(SERVICES)))

# Session support: make start session=my-feature
ifdef session
  export CODE_ROOT   := $(WORKSPACE)/sessions/$(session)/code
endif

.PHONY: start stop status logs clean-logs pull pull-stage sessions

# ============================================================================
# ALL SERVICES
# ============================================================================

start:
	@echo "Starting Saturn services..."
ifdef session
	@echo "$(session)" > $(WORKSPACE)/.logs/.active-session
else
	@echo "workspace" > $(WORKSPACE)/.logs/.active-session
endif
	@for s in $(SCRIPTS); do $$s start; done
	@echo "All services started."

stop:
	@echo "Stopping Saturn services..."
	@for s in $(SCRIPTS); do $$s stop; done
	@echo "All services stopped."

status:
	@active=$$(cat $(WORKSPACE)/.logs/.active-session 2>/dev/null || echo "workspace"); \
	if [ "$$active" = "workspace" ]; then \
		echo "Saturn services status [workspace]"; \
	else \
		echo "Saturn services status [session: $$active]"; \
		export CODE_ROOT=$(WORKSPACE)/sessions/$$active/code; \
	fi; \
	for s in $(SCRIPTS); do $$s status; done

# ============================================================================
# INDIVIDUAL SERVICES — make start-<svc> / stop-<svc> / status-<svc>
#                        make logs-<svc> / errors-<svc>
# ============================================================================

start-fe:
	@scripts/saturn-fe.sh start
stop-fe:
	@scripts/saturn-fe.sh stop
status-fe:
	@scripts/saturn-fe.sh status
logs-fe:
	@scripts/saturn-fe.sh logs
errors-fe:
	@scripts/saturn-fe.sh errors

start-backend:
	@scripts/saturn-backend.sh start
stop-backend:
	@scripts/saturn-backend.sh stop
status-backend:
	@scripts/saturn-backend.sh status
logs-backend:
	@scripts/saturn-backend.sh logs
errors-backend:
	@scripts/saturn-backend.sh errors

start-%:
	@scripts/$*.sh start
stop-%:
	@scripts/$*.sh stop
status-%:
	@scripts/$*.sh status
logs-%:
	@scripts/$*.sh logs
errors-%:
	@scripts/$*.sh errors

# ============================================================================
# UTILITIES
# ============================================================================

logs:
	@for s in $(SERVICES); do \
		echo "\n=== $$s ==="; \
		scripts/$$s.sh errors; \
	done

clean-logs:
	@rm -f $(WORKSPACE)/.logs/*.log && echo "Logs cleared."

build:
	@scripts/create-session $(session)

sessions:
	@echo "Sessions:"
	@for d in sessions/*/; do \
		name=$$(basename "$$d"); \
		info="$$d.info"; \
		if [ -f "$$info" ]; then \
			status=$$(grep '^status:' "$$info" | cut -d' ' -f2-); \
			desc=$$(grep '^description:' "$$info" | cut -d' ' -f2-); \
			printf "  %-20s [%s] %s\n" "$$name" "$$status" "$$desc"; \
		else \
			printf "  %-20s [no metadata]\n" "$$name"; \
		fi; \
	done 2>/dev/null || echo "  No sessions found."

# ============================================================================
# GIT
# ============================================================================

pull:
ifdef session
	@scripts/sync-session $(session)
else
	@echo "Pulling latest on current branch..."
	@for svc in $(SERVICES); do \
		branch=$$(cd $(WORKSPACE)/code/$$svc && git branch --show-current) && \
		(cd $(WORKSPACE)/code/$$svc && git pull origin $$branch --quiet 2>&1) && \
		echo "  [✓] $$svc ($$branch)" || \
		echo "  [✗] $$svc ($$branch) failed"; \
	done
endif

pull-stage:
	@echo "Pulling stage for all repos..."
	@for svc in $(SERVICES); do \
		(cd $(WORKSPACE)/code/$$svc && \
		git fetch origin stage --quiet 2>&1 && \
		git checkout stage --quiet 2>&1 && \
		git pull origin stage --quiet 2>&1) && \
		echo "  [✓] $$svc → stage" || \
		echo "  [✗] $$svc failed"; \
	done
