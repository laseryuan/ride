#!/bin/bash
SESSION_NAME=${HOST_NAME:-0}

tmux new-session -d -s "$SESSION_NAME" -n home bash
tmux send-keys -t "$SESSION_NAME":home "vim" Enter
tmux send-keys -t "$SESSION_NAME":home "C-g" Enter
