#!/bin/bash

if [ -f "$HOME/.ride/chiff/session" ]; then
    ln -sf "$HOME/.ride/chiff/session" "$HOME/.config/chiff/session"
fi

if [ -f "$HOME/.ride/ssh/config" ]; then
    ln -sf "$HOME/.ride/ssh/config" "$HOME/.ssh/config"
fi
