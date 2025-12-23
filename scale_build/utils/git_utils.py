import re
import configparser
import os

from urllib.parse import urlparse

from .run import run
from .paths import GIT_MANIFEST_PATH


# TODO: Let's please use python for git specific bits


def update_git_manifest(git_remote, git_sha, mode='a+'):
    with open(GIT_MANIFEST_PATH, mode) as f:
        f.write(f'{git_remote} {git_sha}\n')


def retrieve_git_remote_and_sha(path):
    return {
        'url': get_origin_uri_filesystem(path),
        'sha': get_short_sha_filesystem(path),
    }


def retrieve_git_branch(path):
    return run(['git', '-C', path, 'branch', '--show-current'], log=False).stdout.strip()


def branch_exists_in_repository(origin, branch):
    cp = run(['git', 'ls-remote', origin], log=False)
    return bool(re.findall(fr'/{branch}\n', cp.stdout, re.M))


def branch_checked_out_locally(path, branch):
    return bool(run(['git', '-C', path, 'branch', '--list', branch], log=False).stdout.strip())


def create_branch(path, base_branch, new_branch):
    run(['git', '-C', path, 'checkout', '-b', new_branch, base_branch])


def get_origin_uri(path):
    return run(['git', '-C', path, 'remote', 'get-url', 'origin'], log=False).stdout.strip()

def get_origin_uri_filesystem(path):
    config_path = os.path.join(path, '.git', 'config')
    config = configparser.ConfigParser(strict=False)
    config.read(config_path)
    return config.get('remote "origin"', 'url')

def get_short_sha_filesystem(repo_path="."):
    try:
        git_dir = os.path.join(repo_path, '.git')
        
        # 1. 读取 HEAD 指向的分支
        with open(os.path.join(git_dir, 'HEAD'), 'r') as f:
            ref = f.read().strip()
        
        if ref.startswith('ref:'):
            # 2. 如果是 ref: refs/heads/master，读取对应文件获取 SHA
            ref_path = os.path.join(git_dir, ref.split(' ')[1])
            with open(ref_path, 'r') as f:
                sha = f.read().strip()
        else:
            # 3. 如果 HEAD 处于 detached 状态，它本身就是 SHA
            sha = ref
            
        return sha[:7]  # 返回短 hash
    except Exception:
        return "unknown"
    
def push_changes(path, api_token, branch):
    url = urlparse(get_origin_uri(path))
    run(['git', '-C', path, 'push', f'https://{api_token}@{url.hostname}{url.path}', branch])


def fetch_origin(path):
    run(['git', '-C', path, 'fetch', 'origin'])


def safe_checkout(path, branch):
    fetch_origin(path)
    if branch_exists_in_repository(get_origin_uri_filesystem(path), branch):
        run(['git', '-C', path, 'checkout', branch])
    else:
        run(['git', '-C', path, 'checkout', '-b', branch])
