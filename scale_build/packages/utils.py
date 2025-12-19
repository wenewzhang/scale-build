import json
from debian.deb822 import Deb822
from scale_build.config import get_env_variable, get_normalized_value


CONSTRAINT_MAPPING = {
    'boolean': bool,
    'integer': int,
    'string': str,
}
DEPENDS_SCRIPT_PATH = './scripts/parse_deps.pl'


def normalize_bin_packages_depends(depends_str):
    return list(filter(lambda k: k and '$' not in k, map(str.strip, depends_str.split(','))))


def normalize_build_depends(build_depends_str):
    deps = []
    for dep in filter(bool, map(str.strip, build_depends_str.split(','))):
        for subdep in filter(bool, map(str.strip, dep.split('|'))):
            index = subdep.find('(')
            if index != -1:
                subdep = subdep[:index].strip()
            deps.append(subdep)
    return deps


def gather_build_time_dependencies(packages, deps, deps_list):
    for dep in filter(lambda p: p in packages, deps_list):
        deps.add(packages[dep].source_name)
        deps.update(gather_build_time_dependencies(
            packages, deps, packages[dep].install_dependencies | packages[dep].build_dependencies
        ))
    return deps


def get_normalized_specified_build_constraint_value(value_schema):
    return get_env_variable(value_schema['name'], CONSTRAINT_MAPPING[value_schema['type']])


def get_normalized_build_constraint_value(value_schema):
    return get_normalized_value(str(value_schema['value']), CONSTRAINT_MAPPING[value_schema['type']])


def parse_control_file(control_path):
    with open(control_path, 'r', encoding='utf-8') as f:
        paragraphs = list(Deb822.iter_paragraphs(f))

    if not paragraphs:
        raise ValueError("Empty or invalid control file")

    source_package = {
        "name": "",
        "build_depends": ""
    }
    binary_packages = []

    # 第一个段通常是 Source 段（也可能有多个 Source？标准是只有一个）
    first_para = paragraphs[0]

    # 提取 source package 信息
    source_name = first_para.get('Source')
    if not source_name:
        # 尝试从其他段找？或 fallback 到第一个 Package？这里严格要求有 Source
        raise ValueError("Missing 'Source' field in control file")
    source_package["name"] = source_name.strip()
    source_package["build_depends"] = first_para.get('Build-Depends', '').strip()

    # 遍历所有段，收集 binary packages（含 'Package' 字段的段）
    for para in paragraphs:
        if 'Package' in para:
            pkg_name = para['Package'].strip()
            depends = para.get('Depends', '').strip()
            binary_packages.append({
                "name": pkg_name,
                "depends": depends
            })

    result = {
        "source_package": source_package,
        "binary_packages": binary_packages
    }

    return json.dumps(result, indent=4, ensure_ascii=False)