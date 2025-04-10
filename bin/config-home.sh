#!/bin/bash

if [ -f "$HOME/.ride/chiff/session" ]; then
    ln -sf "$HOME/.ride/chiff/session" "$HOME/.config/chiff/session"
fi
