#!/usr/bin/env python3
"""Small UI for ~/.config/gh/pr-default-assignees.json (use /usr/bin/python3)."""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tkinter as tk
from pathlib import Path
from tkinter import messagebox, ttk

CONFIG = Path(os.environ.get("GH_PR_ASSIGNEES_CONFIG", Path.home() / ".config/gh/pr-default-assignees.json"))
DEFAULT_HOSTS = ("git.dev.box.net", "github.com")


def load_config() -> dict:
    if CONFIG.exists():
        with CONFIG.open(encoding="utf-8") as f:
            data = json.load(f)
    else:
        data = {}
    data.setdefault("version", 1)
    data.setdefault("agent_ask_before_pr_create", True)
    data.setdefault("agent_ask_message", "Who should be assigned to this PR?")
    data.setdefault("shell_ask_before_pr_create", False)
    data.setdefault("default_assignees", [])
    data.setdefault("teammates", [])
    data.setdefault("hosts", {})
    for h in DEFAULT_HOSTS:
        data["hosts"].setdefault(h, {"assignees": list(data["default_assignees"]) if h != "github.com" else []})
    return data


def save_config(data: dict) -> None:
    CONFIG.parent.mkdir(parents=True, exist_ok=True)
    with CONFIG.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")


class AssigneesApp(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("PR assignees")
        self.geometry("620x680")
        self.data = load_config()
        self._build()
        self._load_fields()

    def _build(self) -> None:
        pad = {"padx": 10, "pady": 6}
        frm = ttk.Frame(self, padding=12)
        frm.pack(fill=tk.BOTH, expand=True)
        ttk.Label(frm, text=f"Config: {CONFIG}", font=("", 10)).pack(anchor=tk.W, **pad)
        ask_frm = ttk.LabelFrame(frm, text="Prompts", padding=8)
        ask_frm.pack(fill=tk.X, **pad)
        self.var_agent_ask = tk.BooleanVar()
        self.var_shell_ask = tk.BooleanVar()
        ttk.Checkbutton(ask_frm, text="Agent must ask in chat before gh pr create", variable=self.var_agent_ask).pack(anchor=tk.W)
        ttk.Checkbutton(ask_frm, text="Cursor approval prompt when gh pr create runs", variable=self.var_shell_ask).pack(anchor=tk.W)
        ttk.Label(ask_frm, text="Question text:").pack(anchor=tk.W, pady=(8, 0))
        self.ent_message = ttk.Entry(ask_frm, width=70)
        self.ent_message.pack(fill=tk.X)
        def_frm = ttk.LabelFrame(frm, text="Default assignees", padding=8)
        def_frm.pack(fill=tk.BOTH, expand=True, **pad)
        self.lst_default = tk.Listbox(def_frm, height=4)
        self.lst_default.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        side = ttk.Frame(def_frm)
        side.pack(side=tk.LEFT, padx=8)
        self.ent_new_default = ttk.Entry(side, width=18)
        self.ent_new_default.pack()
        ttk.Button(side, text="Add", command=self._add_default).pack(fill=tk.X, pady=4)
        ttk.Button(side, text="Remove", command=self._rm_default).pack(fill=tk.X)
        team_frm = ttk.LabelFrame(frm, text="Teammate picker (agent in chat)", padding=8)
        team_frm.pack(fill=tk.BOTH, expand=True, **pad)
        self.lst_team = tk.Listbox(team_frm, height=5)
        self.lst_team.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        tside = ttk.Frame(team_frm)
        tside.pack(side=tk.LEFT, padx=8)
        self.ent_team_login = ttk.Entry(tside, width=20)
        ttk.Label(tside, text="login").pack(anchor=tk.W)
        self.ent_team_login.pack()
        self.ent_team_name = ttk.Entry(tside, width=20)
        ttk.Label(tside, text="display name").pack(anchor=tk.W, pady=(6, 0))
        self.ent_team_name.pack()
        ttk.Button(tside, text="Add", command=self._add_teammate).pack(fill=tk.X, pady=4)
        ttk.Button(tside, text="Remove", command=self._rm_teammate).pack(fill=tk.X)
        ttk.Button(tside, text="Add to defaults", command=self._team_to_default).pack(fill=tk.X, pady=4)
        btn_row = ttk.Frame(frm)
        btn_row.pack(fill=tk.X, **pad)
        ttk.Button(btn_row, text="Save", command=self._save).pack(side=tk.LEFT)

    def _load_fields(self) -> None:
        self.var_agent_ask.set(self.data.get("agent_ask_before_pr_create", True))
        self.var_shell_ask.set(self.data.get("shell_ask_before_pr_create", False))
        self.ent_message.delete(0, tk.END)
        self.ent_message.insert(0, self.data.get("agent_ask_message", ""))
        self.lst_default.delete(0, tk.END)
        for login in self.data.get("default_assignees", []):
            self.lst_default.insert(tk.END, login)
        self.lst_team.delete(0, tk.END)
        for m in self.data.get("teammates", []):
            self.lst_team.insert(tk.END, f"{m.get('name', m.get('login'))} ({m.get('login')})")

    def _add_default(self) -> None:
        login = self.ent_new_default.get().strip()
        if login:
            self.lst_default.insert(tk.END, login)
            self.ent_new_default.delete(0, tk.END)

    def _rm_default(self) -> None:
        sel = self.lst_default.curselection()
        if sel:
            self.lst_default.delete(sel[0])

    def _add_teammate(self) -> None:
        login = self.ent_team_login.get().strip()
        name = self.ent_team_name.get().strip() or login
        if not login:
            return
        self.data.setdefault("teammates", []).append({"login": login, "name": name})
        self.lst_team.insert(tk.END, f"{name} ({login})")
        self.ent_team_login.delete(0, tk.END)
        self.ent_team_name.delete(0, tk.END)

    def _rm_teammate(self) -> None:
        sel = self.lst_team.curselection()
        if not sel:
            return
        idx = sel[0]
        self.lst_team.delete(idx)
        teammates = self.data.get("teammates", [])
        if idx < len(teammates):
            del teammates[idx]

    def _team_to_default(self) -> None:
        sel = self.lst_team.curselection()
        if not sel:
            return
        login = self.data.get("teammates", [])[sel[0]].get("login")
        if login and login not in [self.lst_default.get(i) for i in range(self.lst_default.size())]:
            self.lst_default.insert(tk.END, login)

    def _save(self) -> None:
        self.data["agent_ask_before_pr_create"] = self.var_agent_ask.get()
        self.data["shell_ask_before_pr_create"] = self.var_shell_ask.get()
        self.data["agent_ask_message"] = self.ent_message.get().strip() or "Who should be assigned to this PR?"
        self.data["default_assignees"] = [self.lst_default.get(i) for i in range(self.lst_default.size())]
        for h in DEFAULT_HOSTS:
            self.data.setdefault("hosts", {})
            if h not in self.data["hosts"]:
                self.data["hosts"][h] = {"assignees": list(self.data["default_assignees"]) if h != "github.com" else []}
        save_config(self.data)
        messagebox.showinfo("Saved", f"Wrote {CONFIG}")


if __name__ == "__main__":
    AssigneesApp().mainloop()