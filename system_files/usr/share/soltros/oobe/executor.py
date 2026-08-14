from __future__ import annotations

import os
import re
import subprocess
import threading
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from enum import StrEnum, unique
from typing import Final

from domain import TaskSpec

ANSI_PATTERN: Final = re.compile(r"\x1b\[[0-9;]*m")


@unique
class EventKind(StrEnum):
    STARTED = "started"
    OUTPUT = "output"
    FINISHED = "finished"


@dataclass(frozen=True, slots=True)
class ExecutionEvent:
    kind: EventKind
    task_id: str
    label: str
    message: str = ""
    success: bool | None = None


@dataclass(frozen=True, slots=True)
class TaskResult:
    task_id: str
    label: str
    success: bool
    detail: str


EventCallback = Callable[[ExecutionEvent], None]
CompletionCallback = Callable[[tuple[TaskResult, ...]], None]


class ExecutorBusyError(RuntimeError):
    pass


class TaskExecutor:
    def __init__(self) -> None:
        self._running = False

    @property
    def running(self) -> bool:
        return self._running

    def start(
        self,
        tasks: Sequence[TaskSpec],
        on_event: EventCallback,
        on_complete: CompletionCallback,
    ) -> None:
        if self._running:
            raise ExecutorBusyError("Setup tasks are already running")
        self._running = True
        worker = threading.Thread(
            target=self._run,
            args=(tuple(tasks), on_event, on_complete),
            name="soltros-oobe-tasks",
            daemon=True,
        )
        worker.start()

    def _run(
        self,
        tasks: tuple[TaskSpec, ...],
        on_event: EventCallback,
        on_complete: CompletionCallback,
    ) -> None:
        results: list[TaskResult] = []
        try:
            for task in tasks:
                on_event(ExecutionEvent(EventKind.STARTED, task.task_id, task.label))
                result = self._run_task(task, on_event)
                results.append(result)
                on_event(
                    ExecutionEvent(
                        EventKind.FINISHED,
                        task.task_id,
                        task.label,
                        result.detail,
                        result.success,
                    )
                )
        finally:
            self._running = False
            on_complete(tuple(results))

    @staticmethod
    def _run_task(task: TaskSpec, on_event: EventCallback) -> TaskResult:
        environment = os.environ.copy()
        environment.update({"NO_COLOR": "1", "NONINTERACTIVE": "1"})
        last_line = ""
        for command in task.commands:
            try:
                process = subprocess.Popen(
                    command,
                    shell=False,
                    stdin=subprocess.DEVNULL,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    encoding="utf-8",
                    errors="replace",
                    env=environment,
                    bufsize=1,
                )
            except OSError as error:
                detail = f"Could not start the task: {error.strerror or error}"
                return TaskResult(task.task_id, task.label, False, detail)
            if process.stdout is not None:
                for raw_line in process.stdout:
                    line = ANSI_PATTERN.sub("", raw_line.rstrip())
                    if line:
                        last_line = line
                        on_event(
                            ExecutionEvent(
                                EventKind.OUTPUT,
                                task.task_id,
                                task.label,
                                line,
                            )
                        )
            return_code = process.wait()
            if return_code != 0:
                detail = last_line or f"Command exited with status {return_code}"
                return TaskResult(task.task_id, task.label, False, detail)
        return TaskResult(task.task_id, task.label, True, last_line or "Completed")
