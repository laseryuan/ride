import sys
import argparse

def get_arg_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument('method')
    parser.add_argument('--skip', action='store_true', help='skip compile the bake file')
    parser.add_argument('--only', action='store_true', help='only execute current method')
    parser.add_argument('--bake-args', default="", help='pass arguments for buildx bake')
    return parser

def test_get_arg_parser(mocker):
    import shlex
    sys_args = shlex.split('docker --skip --bake-args="set target.platform=linux/arm64"')

    parser = get_arg_parser()

    args = parser.parse_args(sys_args)
    assert args.method == "docker"
    assert args.skip == True
    assert args.only == False
    assert args.bake_args == "set target.platform=linux/arm64"

    sys_args = shlex.split('deploy --only')

    parser = get_arg_parser()

    args = parser.parse_args(sys_args)
    assert args.method == "deploy"
    assert args.bake_args == ""

