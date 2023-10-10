#!/usr/bin/python3

import chevron
import os
import sys
from read_args import *
from helper import *

class Builder:
    def __init__(self, args):
        self.run_method = args.method
        self.execute_current_task_only = args.only
        self.will_skip_compile_bake_file = args.skip
        self.bake_args = args.bake_args
        self.minor = args.minor

        self.mbuild_dir = "/home/ride/mbuild/"
        #  self.mbuild_dir = "./mbuild/"
        self.output_dir = self.mbuild_dir + "build/"
        self.create_dir_if_not_exist(self.output_dir)

        self.bake_tmpl_path = self.mbuild_dir + "utils/docker-bake.hcl.tmpl"
        self.bake_path = self.output_dir + "docker-bake.hcl"
        self.data=get_data()


    def build_bake(self):
        with open(self.bake_tmpl_path, 'r') as f:
            bake = chevron.render(f, self.data)

        with open(self.bake_path, 'w+') as f:
            f.write(str(bake))

    def get_build_file(self):
        return ".build" if "STAGE" in self.data and self.data["STAGE"] else ""

    def get_build_tag(self):
        return "build-" if "STAGE" in self.data and self.data["STAGE"] else ""

    def build_dockerfile(self, arch_data):
        if_build = self.get_build_file()
        dockerfile_tmpl_path = f'tmpl.Dockerfile{if_build}'
        dockerfile_path = self.output_dir + f'{arch_data["ARCH"]["name"]}/Dockerfile{if_build}'
        with open(dockerfile_tmpl_path, 'r') as f:
            dockerfile = chevron.render(f, arch_data)
        with open(dockerfile_path, 'w') as f:
            f.write(str(dockerfile))

    def create_dir_if_not_exist(self, arch_path):
        if not os.path.exists(arch_path):
            os.makedirs(arch_path)

    def build_dockerfiles(self):
        for arch in self.data['ARCH']:
            arch_path = self.output_dir + arch['name']
            self.create_dir_if_not_exist(arch_path)
            arch_data = self.data.copy()
            arch_data['ARCH'] = arch
            self.build_dockerfile(arch_data)

    def config(self):
        self.build_bake()
        self.build_dockerfiles()

    def docker(self):
        ret = os.system(
          "docker buildx bake -f " + self.output_dir + "docker-bake.hcl " + self.bake_args
          )
        if ret != 0:
            sys.exit(1)

    def push_to_repo(self):
        repo = self.data["REPO"]
        if_build = self.get_build_tag()
        for arch in self.data['ARCH']:
            if arch['enable']:
                tag = f'{if_build}{arch["tag"]}'
                tag_new = f'{if_build}{self.data["IMAGE_VERSION"]}-{arch["tag"]}'
                push_cmd = f'docker tag {repo}:{tag} lasery/{repo}:{tag_new}'
                os.system(push_cmd)
                push_cmd = f'docker push lasery/{repo}:{tag_new}'
                os.system(push_cmd)
                if self.minor:
                    tag_minor = f'{tag_new}-{self.minor}'
                    push_cmd = f'docker tag {repo}:{tag} lasery/{repo}:{tag_minor}'
                    os.system(push_cmd)
                    push_cmd = f'docker push lasery/{repo}:{tag_minor}'
                    os.system(push_cmd)

    def repo_manifest(self, version):
        repo = f'lasery/{self.data["REPO"]}'
        if_build = self.get_build_tag()
        tag = f'{if_build}{version}'
        for arch in self.data['ARCH']:
            if arch['enable']:
                tag_new = f'{if_build}{self.data["IMAGE_VERSION"]}-{arch["tag"]}'
                push_cmd = f'docker manifest create -a {repo}:{tag}  {repo}:{tag_new}'
                os.system(push_cmd)
                push_cmd = f'docker manifest annotate {repo}:{tag}  {repo}:{tag_new} --arch {arch["arch"]}{" --variant " +  arch["variant"] if "variant" in arch else ""}'
                os.system(push_cmd)
        os.system(f'docker manifest push -p {repo}:{tag}')
        os.system(f'docker manifest inspect {repo}:{tag}')

    def push(self):
        if not self.execute_current_task_only:
            self.docker()
        version = self.data["IMAGE_VERSION"]
        self.push_to_repo()
        self.repo_manifest(version)

    def deploy(self):
        if not self.execute_current_task_only:
            self.push()
        version = "latest"
        self.repo_manifest(version)

    def run(self):
        if not self.will_skip_compile_bake_file:
            self.config()
        getattr(self, self.run_method)()

def get_builder():
    sys_args = sys.argv[1:]
    parser = get_arg_parser()
    args = parser.parse_args(sys_args)

    return Builder(args)

if __name__ == '__main__':
    builder = get_builder()
    builder.run()

# pytest utils/build.py -s
def test_create_builder(mocker):
    mocker.patch(
        "sys.argv",
        [
            "builder.py",
            "docker",
            "--only",
        ],
    )
    builder = get_builder()

def test_Builder_push_to_repo(mocker):
    mocker.patch(
        "sys.argv",
        [
            "builder.py",
            "push",
            "--only",
            "--minor=abcde",
        ],
    )
    mocker.patch('os.system')
    builder = get_builder()
    builder.run()
