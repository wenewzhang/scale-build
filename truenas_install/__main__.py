# -*- coding=utf-8 -*-
import json
import platform
import sys

from .i18n import _, set_language


# LEGACY_TRUENAS_VERSION_ERR_MSG = (
#     "Migrating TrueNAS CORE to TrueNAS SCALE 24.10 (or later) using update file upload is not supported. "
#     "Please migrate with the latest 24.04 release update file or back up the TrueNAS configuration, perform a "
#     "fresh install, and restore from the configuration backup."
# )
# INSTALLER_PYTHON_MIN_VERSION_MINOR = 10
# version = sys.version_info


def write_error(error: str, raise_=False, prefix="Error: "):
    sys.stdout.write(json.dumps({"error": prefix + error}) + "\n")
    sys.stdout.flush()

    if raise_:
        raise Exception(error)


# if __name__ == "__main__":
#     if platform.system().upper() == "FREEBSD":
#         write_error(LEGACY_TRUENAS_VERSION_ERR_MSG)
#         sys.exit(2)

# if version.major < 3 or version.minor < INSTALLER_PYTHON_MIN_VERSION_MINOR:
#     write_error(LEGACY_TRUENAS_VERSION_ERR_MSG, raise_=True)


from collections import defaultdict  # noqa
import contextlib  # noqa
from datetime import datetime  # noqa
import itertools  # noqa
import logging  # noqa
import os  # noqa
import re  # noqa
import shutil  # noqa
import sqlite3  # noqa
import subprocess  # noqa
import sys  # noqa
import tempfile  # noqa

from licenselib.license import ContractType, License  # noqa

from .dhs import TRUENAS_DATA_HIERARCHY  # noqa
from .fhs import TRUENAS_DATASETS  # noqa
from .utils import getmntinfo, get_pids  # noqa
from .logger import logger  # noqa
from .simple_writer import writer  # noqa

BIOS_BOOT_PARTITION_GUID = "21686148-6449-6E6F-744E-656564454649"
EFI_SYSTEM_PARTITION_GUID = "C12A7328-F81F-11D2-BA4B-00A0C93EC93B"

RE_UNSQUASHFS_PROGRESS = re.compile(r"\[.+]\s+(?P<extracted>[0-9]+)/(?P<total>[0-9]+)\s+(?P<progress>[0-9]+)%")
run_kw = dict(check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, encoding="utf-8", errors="ignore")


def write_progress(progress, message):
    sys.stdout.write(json.dumps({"progress": progress, "message": message}) + "\n")
    sys.stdout.flush()


def run_command(cmd, **kwargs):
    logger.debug("cmd:%s", ' '.join(cmd))
    writer.writeln(f"{' '.join(cmd)}")
    try:
        return subprocess.run(cmd, **dict(run_kw, **kwargs))
    except subprocess.CalledProcessError as e:
        write_error(f"Command {cmd} failed with exit code {e.returncode}: {e.stderr}")
        logger.error("Command %s \nfailed with exit code %s: %s", ' '.join(cmd), e.returncode, e.stderr)
        raise


def get_partition(disk, partition):
    paths = [f"/dev/{disk}{partition}", f"/dev/{disk}p{partition}"]
    for path in paths:
        if os.path.exists(path):
            return path
    raise Exception(f"Neither {' or '.join(paths)} exist")


def get_partition_guid(disk, partition):
    return dict(map(
        lambda s: s.split(": ", 1),
        run_command(["sgdisk", "-i", str(partition), f"/dev/{disk}"]).stdout.splitlines(),
    ))["Partition GUID code"].split()[0]


def dict_factory(cursor, row):
    d = {}
    for idx, col in enumerate(cursor.description):
        d[col[0]] = row[idx]
    return d


def query_row(query, database_path, prefix=None):
    database_path = database_path
    conn = sqlite3.connect(database_path)
    try:
        conn.row_factory = dict_factory
        c = conn.cursor()
        try:
            c.execute(query)
            result = c.fetchone()
        finally:
            c.close()
    finally:
        conn.close()
    if prefix:
        result = {k.replace(prefix, ""): v for k, v in result.items()}
    return result


def query_config_table(table, database_path, prefix=None):
    return query_row(f"SELECT * FROM {table}", database_path, prefix)


def configure_serial_port(root, db_path):
    if not os.path.exists(db_path):
        return

    # We would like to explicitly enable/disable serial-getty in the new BE based on db configuration
    advanced = query_config_table("system_advanced", db_path, prefix="adv_")
    if advanced["serialconsole"]:
        run_command(
            ["chroot", root, "systemctl", "enable", f"serial-getty@{advanced['serialport']}.service"], check=False
        )


def database_path(root):
    return os.path.join(root, "data/freenas-v1.db")


def enable_system_user_services(root, old_root):
    configure_serial_port(root, database_path(old_root))
    enable_user_services(root, old_root)


def enable_user_services(root, old_root):
    user_services_file = os.path.join(old_root, "data/user-services.json")
    if not os.path.exists(user_services_file):
        return

    with open(user_services_file, 'r') as f:
        systemd_units = [
            srv for srv, enabled in json.loads(f.read()).items() if enabled
        ]

    if systemd_units:
        run_command(["chroot", root, "systemctl", "enable"] + systemd_units, check=False)


def configure_system_for_zectl(boot_pool):
    root_ds = os.path.join(boot_pool, "ROOT")
    set_prop = run_command([
        "zfs", "get", "-H", "-o", "value", "org.zectl:bootloader", root_ds
    ]).stdout.strip() != 'grub'
    if set_prop:
        run_command(["zfs", "set", "org.zectl:bootloader=grub", root_ds])


def read_license(root):
    license_path = os.path.join(root, "data/license")
    try:
        with open(license_path) as f:
            return License.load(f.read().strip('\n'))
    except Exception:
        return None


def andjoin(array, singular, plural):
    if len(array) == 1:
        return f"{array[0]} {singular}"

    if len(array) == 2:
        return f"{array[0]} and {array[1]} {plural}"

    return ", ".join(array[:-1]) + f" and {array[-1]} {plural}"


def precheck(old_root):
    services = [
        ("dynamicdns", "Dynamic DNS", "inadyn", None),
        ("openvpn_client", "OpenVPN Client", "openvpn", "client.conf"),
        ("openvpn_server", "OpenVPN Server", "openvpn", "server.conf"),
        ("rsync", "Rsync", "rsync", "--daemon"),
        ("s3", "S3", "minio", None),
        ("tftp", "TFTP", "in.tftpd", None),
        ("webdav", "WebDAV", "apache2", None),
    ]

    if old_root is not None:
        enabled_services = []
        db_path = database_path(old_root)
        if os.path.exists(db_path):
            for service, title, process_name, cmdline in services:
                try:
                    if query_row(
                        f"SELECT * FROM services_services WHERE srv_service = '{service}' AND srv_enable = 1",
                        db_path,
                    ) is not None:
                        enabled_services.append(title)
                except Exception:
                    pass

        processes = defaultdict(list)
        for p in get_pids():
            processes[p.name].append(p)
        running_services = []
        for service, title, process_name, cmdline in services:
            if process_name in processes:
                # If we report an enabled service, we don't want to report the same service running.
                if title not in enabled_services:
                    for proc in processes[process_name]:
                        if cmdline is not None:
                            if cmdline not in proc.cmdline.decode(errors="ignore"):
                                continue

                        try:
                            with open(f"/proc/{proc.pid}/cgroup") as f:
                                cgroups = f.read().strip()
                        except FileNotFoundError:
                            cgroups = ""

                        # https://forums.truenas.com/t/disable-webdav-service-from-cli-or-by-modifying-config-db/2795/4
                        if cgroups and "kubepods" in cgroups or "docker" in cgroups or "/payload/" in cgroups:
                            continue

                        running_services.append(title)
                        break

        if enabled_services or running_services:
            if (
                (licenseobj := read_license(old_root)) and
                ContractType(licenseobj.contract_type) in [ContractType.silver, ContractType.gold] and
                licenseobj.contract_end > datetime.utcnow().date()
            ):
                fatal = True
                text = (
                    "There are active configured services on this system that are not present in the new version. To "
                    "avoid any loss of system services, please contact iXsystems Support to schedule a guided upgrade. "
                    "Additional details are available from https://www.truenas.com/docs/scale/scaledeprecatedfeatures/."
                )
            else:
                fatal = False
                text = (
                    "There are active configured services on this system that are not present in the new version. "
                    "Upgrading this system deletes these services and saved settings: "
                    f"{andjoin(sorted(enabled_services + running_services), 'service', 'services')}. "
                    "This disrupts any system usage that relies on these active services."
                )

            return fatal, text


def main():
    logger.info("Starting zuti installation...")
    input = json.loads(sys.stdin.read())
    logger.info("input: %s", input)
    
    # 设置语言（从 input 中获取，默认为英文）
    language = input.get("language", "en")
    set_language(language)
    
    version = input.get("version", None)
    is_fresh_install = version is None
    boot_mode = input.get("boot_mode", "UEFI")
    # if input.get("precheck"):
    #     if precheck_result := precheck(old_root):
    #         fatal, text = precheck_result
    #         if fatal:
    #             write_error(text)
    #             sys.exit(2)
    #         else:
    #             write_error(text, prefix="")

    #     sys.exit(0)

    # cleanup = input.get("cleanup", True)
    disks = input["disks"]
    # authentication_method = input.get("authentication_method", None)
    pool_name = input["pool_name"]
    # post_install = input.get("post_install", None)
    # sql = input.get("sql", None)
    src = input["src"]
    boot_mode = input.get("boot_mode")

    with open(os.path.join(src, "manifest.json")) as f:
        manifest = json.load(f)
      
    # old_bootfs_prop = run_command(["zpool", "get", "-H", "-o", "value", "bootfs", pool_name]).stdout.strip()
    # old_root_dataset = None
    # if old_root is not None:
    #     for i in getmntinfo():
    #         if i.mountpoint == old_root:
    #             old_root_dataset = i.mount_source
    #             break
    if is_fresh_install:
        write_progress(0, _("creating_dataset"))
    # if input.get("dataset_name"):
    #     dataset_name = input["dataset_name"]
    # else:
        dataset_name = f"{pool_name}/ROOT/{manifest['version']}"

        existing_datasets = set(filter(None, run_command(["zfs", "list", "-H", "-o", "name"]).stdout.split("\n")))
        if dataset_name in existing_datasets:
            for i in itertools.count(1):
                probe_dataset_name = f"{dataset_name}-{i}"
                if probe_dataset_name not in existing_datasets:
                    dataset_name = probe_dataset_name
                    break
                
        # run_command(["zfs", "create", "-o", "mountpoint=none", f"{pool_name}/ROOT"])     
        run_command(["udevadm", "trigger"])        
        
        tmpdir= '/mnt/a'
        run_command(["mkdir", "-p", tmpdir])

        run_command(["zfs", "create", "-o", "canmount=noauto", "-o", f"mountpoint={tmpdir}", f"{dataset_name}"])
        run_command(["zpool", "set", f"bootfs={dataset_name}", pool_name])   
        # run_command(["mkdir", "-p", tmpdir])
        # run_command(["mount", "-t", "zfs", dataset_name, tmpdir])          
        run_command(["zpool", "export", "-f", pool_name])
        run_command(["zpool", "import", pool_name])
        run_command(["zfs", "mount", dataset_name])   
        # run_command(["zpool", "import", "-R", f"{tmpdir}", pool_name])

        check_mountpoint(tmpdir)
        
        cmd = [
            "unsquashfs",
            "-d", tmpdir,
            "-f",
            "-da", "16",
            "-fr", "16",
            # "-exclude-file", exclude_list_file.name,
            os.path.join(src, "rootfs.squashfs"),
        ]
        p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        stdout = ""
        buffer = b""
        for char in iter(lambda: p.stdout.read(1), b""):
            buffer += char
            if char == b"\n":
                stdout += buffer.decode("utf-8", "ignore")
                buffer = b""

            if buffer and buffer[0:1] == b"\r" and buffer[-1:] == b"%":
                if m := RE_UNSQUASHFS_PROGRESS.match(buffer[1:].decode("utf-8", "ignore")):
                    write_progress(
                        int(m.group("extracted")) / int(m.group("total")) * 0.5,
                        _("extracting"),
                    )
                    buffer = b""

        p.wait()
        if p.returncode != 0:
            write_error(_("unsquashfs_failed", exit_code=p.returncode, output=stdout))
            raise subprocess.CalledProcessError(p.returncode, cmd, stdout)    
        
        run_command(["chmod", "+x", f"{tmpdir}/usr/bin/dpkg"])
        run_command(["chmod", "+x", f"{tmpdir}/usr/bin/apt"])     
        # 创建并挂载 proc, sys, dev
        run_command(["mkdir", "-p", f"{tmpdir}/proc", f"{tmpdir}/sys", f"{tmpdir}/dev"])
        run_command(["mount", "-t", "proc", "proc", f"{tmpdir}/proc"])
        run_command(["mount", "-t", "sysfs", "sys", f"{tmpdir}/sys"])
        run_command(["mount", "--bind", "/dev", f"{tmpdir}/dev"])
        hostname = 'onenas'
        run_command(["sh", "-c", f"echo '{hostname}' > {tmpdir}/etc/hostname"])
        run_command(["sh", "-c", f"echo -e '127.0.1.1\\t{hostname}' >> {tmpdir}/etc/hosts"])
        run_command(["sh", "-c", f"""cat <<'EOF' > {tmpdir}/etc/apt/sources.list
deb http://deb.debian.org/debian/ trixie main non-free-firmware contrib
deb-src http://deb.debian.org/debian/ trixie main non-free-firmware contrib

deb http://deb.debian.org/debian-security trixie-security main non-free-firmware contrib
deb-src http://deb.debian.org/debian-security/ trixie-security main non-free-firmware contrib

# trixie-updates, to get updates before a point release is made;
deb http://deb.debian.org/debian trixie-updates main non-free-firmware contrib
deb-src http://deb.debian.org/debian trixie-updates main non-free-firmware contrib
EOF"""])
        run_command(["sh", "-c", f"echo 'REMAKE_INITRD=yes' > {tmpdir}/etc/dkms/zfs.conf"])
        run_command(["chroot", tmpdir, "systemctl", "enable", "zfs.target"])
        run_command(["chroot", tmpdir, "systemctl", "enable", "zfs-import-cache"])
        run_command(["chroot", tmpdir, "systemctl", "enable", "zfs-mount"])
        run_command(["chroot", tmpdir, "systemctl", "enable", "zfs-import.target"])
        run_command(["chroot", tmpdir, "systemctl", "enable", "systemd-resolved"])
        run_command(["chroot", tmpdir, "systemctl", "enable", "systemd-networkd"])
        # run_command(["chroot", tmpdir, "dpkg-reconfigure", "locales"])
        # run_command(["chroot", tmpdir, "dpkg-reconfigure", "tzdata"])
        # run_command(["chroot", tmpdir, "dpkg-reconfigure", "keyboard-configuration"])
        # run_command(["chroot", tmpdir, "dpkg-reconfigure", "console-setup"])
        run_command(["chroot", tmpdir, "update-initramfs", "-c", "-k", "all"])
        run_command(["chroot", tmpdir, "zfs", "set", f"org.zfsbootmenu:commandline=quiet", f"{pool_name}/ROOT"])
        if boot_mode == 'UEFI':                
            for disk in disks:
                first_part = f"/dev/{disk}1"
                run_command(["chroot", tmpdir, "mkfs.vfat", "-F32", first_part])
                blkid_output = run_command(["chroot", tmpdir,"sh", "-c", f"blkid | grep {first_part} | cut -d ' ' -f 2"]).stdout.strip()
                bootfs = f"{blkid_output} /boot/efi vfat defaults 0 0"
                run_command(["chroot", tmpdir,"sh", "-c", f"echo {bootfs} >> /etc/fstab"])
                run_command(["chroot", tmpdir,"mkdir", "-p", "/boot/efi"])
                run_command(["chroot", tmpdir, "mount", "/boot/efi"])
                is_mount_efi = check_mountpoint_chroot("/boot/efi", tmpdir)
                if is_mount_efi:
                    run_command(["chroot", tmpdir, "mount", "-t", "efivarfs", "efivarfs", "/sys/firmware/efi/efivars"])

                    # run_command(["chroot", tmpdir,"mkdir", "-p", "/boot/efi/zbm"])
                    # run_command(["cp", "-rf", f"/cdrom/scripts/zbm/*", f"{tmpdir}/boot/efi/zbm/."])
                    shutil.copytree("/cdrom/scripts/zbm", f"{tmpdir}/boot/efi/zbm", dirs_exist_ok=True)
                    # for disk in disks:
                    run_command(["chroot", tmpdir, "efibootmgr", "-c",
                                    "-d", f"/dev/{disk}",
                                    "-p", "1",
                                    "-L", "OneNAS[zuti-0.1]",
                                    "-l", "\zbm\VMLINUZ.EFI"])
                else:
                    logger.error("Can not mount /boot/efi !!!")
            
        run_command(["chroot", tmpdir, "sh", "-c", "echo 'root:root' | chpasswd"])
        # run_command(["chroot", tmpdir, "sh", "-c", "sed -i 's|172\\.17\\.0\\.2:3142/||g' /etc/apt/sources.list"])
        run_command(["chroot", tmpdir, "ssh-keygen", "-A"])
    else:
        logger.info("Should upgrade here!")

    # try:
    #     cloned_datasets = set()
    #     for entry in TRUENAS_DATASETS:
    #         entry_dataset_name = f"{dataset_name}/{entry['name']}"

    #         options = ["-o", "mountpoint=legacy", "-o", "canmount=noauto"]
    #         if "NOSUID" in entry["options"]:
    #             options.extend(["-o", "setuid=off", "-o", "devices=off"])
    #         if "NOSETUID" in entry["options"]:
    #             options.extend(["-o", "setuid=off"])
    #         if "NOEXEC" in entry["options"]:
    #             options.extend(["-o", "exec=off"])
    #         if "NODEV" in entry["options"]:
    #             options.extend(["-o", "devices=off"])
    #         if "DEV" in entry["options"]:
    #             options.extend(["-o", "devices=on"])
    #         if "NOACL" in entry['options']:
    #             options.extend(["-o", "acltype=off", "-o", "aclmode=discard"])
    #         if "POSIXACL" in entry["options"]:
    #             options.extend(["-o", "acltype=posixacl", "-o", "aclmode=discard"])
    #         if "NOATIME" in entry["options"]:
    #             options.extend(["-o", "atime=off"])

    #         if entry.get("clone"):
    #             if old_root_dataset is not None:
    #                 old_dataset = f"{old_root_dataset}/{entry['name']}"
    #                 snapshot_name = f"{old_dataset}@install-{datetime.utcnow().strftime('%Y-%m-%d-%H-%M-%S')}"
    #                 result = run_command(["zfs", "snapshot", snapshot_name], check=False)
    #                 if result.returncode == 0:
    #                     run_command(["zfs", "clone"] + options + [snapshot_name, entry_dataset_name])
    #                     cloned_datasets.add(entry["name"])
    #                     continue

    #         run_command(["zfs", "create", "-u"] + options + [entry_dataset_name])

    #     with tempfile.TemporaryDirectory() as root:
    #         undo = []
    #         ds_info = []
    #         run_command(["mount", "-t", "zfs", dataset_name, root])
    #         try:
    #             write_progress(0, "Extracting")

    #             for entry in TRUENAS_DATASETS:
    #                 this_ds = entry['name']
    #                 ds_name = f"{dataset_name}/{this_ds}"
    #                 ds_path = entry.get("mountpoint") or f"/{entry['name']}"
    #                 ds_guid = run_command(["zfs", "list", "-o", "guid", "-H", ds_name]).stdout.strip()

    #                 mp = os.path.join(root, ds_path[1:])
    #                 os.makedirs(mp, exist_ok=True)
    #                 logger.debug("Mounting %s to %s", ds_name, mp)
    #                 run_command(["mount", "-t", "zfs", f"{dataset_name}/{this_ds}", mp])
    #                 ds_info.append({"ds": ds_name, "guid": ds_guid, "fhs_entry": entry})
    #                 undo.append(["umount", mp])

    #             data_exclude = [
    #                 "data/factory-v1.db",
    #                 "data/manifest.json",
    #                 "data/sentinels",
    #                 "data/uploaded.db",
    #             ]

    #             if "data" in cloned_datasets:
    #                 for excluded in data_exclude:
    #                     remove = f"{root}/{excluded}"
    #                     try:
    #                         shutil.rmtree(remove)
    #                     except NotADirectoryError:
    #                         try:
    #                             os.unlink(remove)
    #                         except FileNotFoundError:
    #                             pass
    #                     except FileNotFoundError:
    #                         pass

    #             exclude_list = []
    #             root_as_bytes = root.encode()
    #             for walk_root, dirs, files in os.walk(root_as_bytes):
    #                 for file in files:
    #                     exclude_list.append(os.path.relpath(os.path.join(walk_root, file), root_as_bytes))

    #             with tempfile.NamedTemporaryFile() as exclude_list_file:
    #                 exclude_list_file.write(b"\n".join(exclude_list))
    #                 exclude_list_file.flush()

    #                 cmd = [
    #                     "unsquashfs",
    #                     "-d", root,
    #                     "-f",
    #                     "-da", "16",
    #                     "-fr", "16",
    #                     "-exclude-file", exclude_list_file.name,
    #                     os.path.join(src, "rootfs.squashfs"),
    #                 ]
    #                 p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    #                 stdout = ""
    #                 buffer = b""
    #                 for char in iter(lambda: p.stdout.read(1), b""):
    #                     buffer += char
    #                     if char == b"\n":
    #                         stdout += buffer.decode("utf-8", "ignore")
    #                         buffer = b""

    #                     if buffer and buffer[0:1] == b"\r" and buffer[-1:] == b"%":
    #                         if m := RE_UNSQUASHFS_PROGRESS.match(buffer[1:].decode("utf-8", "ignore")):
    #                             write_progress(
    #                                 int(m.group("extracted")) / int(m.group("total")) * 0.5,
    #                                 "Extracting",
    #                             )
    #                             buffer = b""

    #                 p.wait()
    #                 if p.returncode != 0:
    #                     write_error(f"unsquashfs failed with exit code {p.returncode}: {stdout}")
    #                     raise subprocess.CalledProcessError(p.returncode, cmd, stdout)

    #             write_progress(0.5, "Performing post-install tasks")

    #             for entry in TRUENAS_DATASETS:
    #                 if not (force_mode := entry.get("mode")):
    #                     continue

    #                 os.chmod(f"{root}/{entry['name']}", force_mode)

    #             with open(f"{root}/conf/truenas_root_ds.json", "w") as f:
    #                 f.write(json.dumps(ds_info, indent=4))

    #             with contextlib.suppress(FileNotFoundError):
    #                 # We want to remove this for fresh installation + upgrade both
    #                 # In this case, /etc/machine-id would be treated as the valid
    #                 # machine-id which it will be otherwise as well if we use
    #                 # systemd-machine-id-setup --print to confirm but just to be cautious
    #                 we remove this as it will be generated automatically by systemd then
    #                 # complying with /etc/machine-id contents
    #                 os.unlink(f"{root}/var/lib/dbus/machine-id")

    #             setup_machine_id = False
    #             configure_serial = False
    #             if old_root is not None:
    #                 write_progress(0.51, "Copying previous configuration")

    #                 rsync = ["etc/hostid"]
    #                 if "data" not in cloned_datasets:
    #                     rsync.append("data")
    #                 if "root" not in cloned_datasets:
    #                     rsync.append("root")
    #                 rsync.append("etc/machine-id")
    #                 if "home" not in cloned_datasets:
    #                     rsync.append("home")
    #                 if os.path.exists(f"{old_root}/var/lib/libvirt/qemu/nvram"):
    #                     rsync.append("var/lib/libvirt/qemu/nvram")
    #                 if os.path.exists(f"{old_root}/var/lib/netdata"):
    #                     rsync.append("var/lib/netdata")
    #                 if os.path.exists(f"{old_root}/var/lib/snmp"):
    #                     rsync.append("var/lib/snmp")
    #                 if os.path.exists(f"{old_root}/var/lib/syslog-ng/syslog-ng.persist"):
    #                     rsync.append("var/lib/syslog-ng/syslog-ng.persist")
    #                 if "var/log" not in cloned_datasets:
    #                     try:
    #                         logs = os.listdir(f"{old_root}/var/log")
    #                     except Exception:
    #                         pass
    #                     else:
    #                         for log in logs:
    #                             if log.startswith(("failover.log", "fenced.log", "middlewared.log")):
    #                                 rsync.append(f"var/log/{log}")

    #                 run_command([
    #                     "rsync", "-aRx",
    #                 ] + sum([
    #                     ["--exclude", excluded]
    #                     for excluded in data_exclude
    #                 ], []) + rsync + [
    #                     f"{root}/",
    #                 ], cwd=old_root)

    #                 write_progress(0.52, "Migrating configuration database")
    #                 run_command(["chroot", root, "migrate"])

    #                 enable_system_user_services(root, old_root)
    #             else:
    #                 run_command(["cp", "/etc/hostid", f"{root}/etc/"])

    #                 with open(f"{root}/data/first-boot", "w"):
    #                     pass
    #                 with open(f"{root}/data/truenas-eula-pending", "w"):
    #                     pass

    #                 setup_machine_id = configure_serial = True

    #                 # Copy all files from ISO's data to new root's data (only includes .vendor right now)
    #                 run_command(["cp", "-r", "/data/.", f"{root}/data/"])

    #             # We only want /data itself (without contents) and /data/subsystems to be 755
    #             # whereas everything else should be 700
    #             # Doing this here is important so that we cover both fresh install and upgrade case
    #             run_command(["chmod", "-R", "u=rwX,g=,o=", f"{root}/data"])
    #             for entry in TRUENAS_DATA_HIERARCHY:
    #                 entry_path = os.path.join(root, entry["path"])
    #                 os.makedirs(entry_path, exist_ok=True)
    #                 if owner_config := entry.get("owner"):
    #                     run_command([
    #                         "chown", *(["-R"] if entry["recursive_ownership"] else []),
    #                         f"{owner_config['uid']}:{owner_config['gid']}", entry_path
    #                     ])

    #                 if mode := entry.get("mode"):
    #                     mode = f"u={mode['user']},g={mode['group']},o={mode['other']}"
    #                     run_command(["chmod", *(["-R"] if entry["recursive"] else []), mode, entry_path])

    #             if setup_machine_id:
    #                 with contextlib.suppress(FileNotFoundError):
    #                     os.unlink(f"{root}/etc/machine-id")

    #                 run_command(["systemd-machine-id-setup", f"--root={root}"])
    #            
    #             # 确保挂载点目录存在
    #             mount_points = [
    #                 f"{root}/dev",
    #                 f"{root}/proc",
    #                 f"{root}/sys",
    #                 f"{root}/boot/grub",
    #             ]

    #             for mp in mount_points:
    #                 try:
    #                     os.makedirs(mp, exist_ok=True)  # exist_ok=True 避免重复创建时报错
    #                 except OSError as e:
    #                     logger.debug("⚠️  Warning: Failed to create directory %s: %s", mp, e)

    #             run_command(["mount", "-t", "devtmpfs", "udev", f"{root}/dev"])
    #             undo.append(["umount", f"{root}/dev"])

    #             run_command(["mount", "-t", "proc", "none", f"{root}/proc"])
    #             undo.append(["umount", f"{root}/proc"])

    #             run_command(["mount", "-t", "sysfs", "none", f"{root}/sys"])
    #             undo.append(["umount", f"{root}/sys"])
    #             if os.path.exists("/sys/firmware/efi"):
    #                 undo.append(["umount", f"{root}/sys/firmware/efi/efivars"])

    #             run_command(["mount", "-t", "zfs", f"{pool_name}/grub", f"{root}/boot/grub"])
    #             undo.append(["umount", f"{root}/boot/grub"])

    #             # It will legitimately exit with code 2 if initramfs must be updated (which we'll do anyway)
    #             # write_progress(0.55, "Running autotune")
    #             # run_command(["chroot", root, "/usr/local/bin/truenas-autotune.py", "--skip-unknown"],
    #             #             check=False)

    #             # if authentication_method is not None:
    #             #     write_progress(0.56, "Setting up authentication")
    #             #     run_command(["chroot", root, "/usr/local/bin/truenas-set-authentication-method.py"],
    #             #                 input=json.dumps(authentication_method))

    #             # if post_install is not None or sql is not None:
    #             #     write_progress(0.57, "Persisting miscellaneous configuration")

    #             #     if post_install is not None:
    #             #         with open(f"{root}/data/post-install.json", "w") as f:
    #             #             json.dump(post_install, f)

    #             #     if sql is not None:
    #             #         run_command(["chroot", root, "sqlite3", "/data/freenas-v1.db"], input=sql)

    #             # if configure_serial:
    #             #     write_progress(0.58, "Configuring serial port")
    #             #     configure_serial_port(root, os.path.join(root, "data/freenas-v1.db"))

    #             # Set bootfs before running update-grub
    #             run_command(["zpool", "set", f"bootfs={dataset_name}", pool_name])

    #             # write_progress(0.7, "Preparing NVDIMM configuration")
    #             # run_command(["chroot", root, "/usr/local/bin/truenas-nvdimm.py"])
    #             # write_progress(0.71, "Preparing GRUB configuration")
    #             # run_command(["chroot", root, "/usr/local/bin/truenas-grub.py"])
    #             # write_progress(0.8, "Updating initramfs")
    #             # cp = run_command([f"{root}/usr/local/bin/truenas-initrd.py", "-f", root], check=False)
    #             # if cp.returncode > 1:
    #             #     raise subprocess.CalledProcessError(
    #             #         cp.returncode, f'Failed to execute truenas-initrd: {cp.stderr}'
    #             #     )
    #             write_progress(0.9, "Updating GRUB")
    #             run_command(["chroot", root, "update-grub"])
    #             write_progress(0.91, "after update-grub ")
    #             logger.info("after 91...")
    #             # We would like to configure fips bit as well here
    #             # write_progress(0.95, "Configuring FIPS")
    #             # run_command(["chroot", root, "/usr/bin/configure_fips"])
    #             run_grub_install = old_root is None
    #                
    #             logger.debug("run_grub_install 1: %s", run_grub_install)

    #             if run_grub_install is False:
    #                 # We will check if current BE has a different version of grub then the new/upcoming one
    #                 # and if that is the case, we want to update ESP with newer grub binaries
    #                 cp = run_command(["grub-install", "--version"])
    #                 be_cp = run_command(["chroot", root, "grub-install", "--version"])
    #                 # We expect something like "grub-install (GRUB) 2.12-1~bpo12+1"
    #                 run_grub_install = cp.stdout.strip().split()[-1] != be_cp.stdout.strip().split()[-1]

    #             logger.debug("run_grub_install 2: %s", run_grub_install)

    #             if run_grub_install:
    #                 write_progress(0.96, "Installing GRUB")

    #                 if os.path.exists("/sys/firmware/efi"):
    #                     cmd = ["mount", "-t", "efivarfs", "efivarfs", f"{root}/sys/firmware/efi/efivars"]
    #                     try:
    #                         subprocess.run(cmd, **run_kw)
    #                     except subprocess.CalledProcessError as e:
    #                         if e.returncode == 32 and "efivarfs already mounted on" in e.stderr:
    #                             pass
    #                         else:
    #                             write_error(f"Command {cmd} failed with exit code {e.returncode}: {e.stderr}")
    #                             raise

    #                     # Clean up dumps from NVRAM to prevent
    #                     # "failed to register the EFI boot entry: No space left on device"
    #                     for item in os.listdir("/sys/firmware/efi/efivars"):
    #                         if item.startswith("dump-"):
    #                             with contextlib.suppress(Exception):
    #                                 os.unlink(os.path.join("/sys/firmware/efi/efivars", item))

    #                 os.makedirs(f"{root}/boot/efi", exist_ok=True)
    #                 for i, disk in enumerate(disks):
    #                     if old_root is None:
    #                         # Fresh installation - we know the layout
    #                         efi_partition_number = 2
    #                         run_command([
    #                             "chroot", root, "grub-install", "--target=i386-pc", f"/dev/{disk}"
    #                         ])
    #                     else:
    #                         partition_1_guid = None
    #                         try:
    #                             partition_1_guid = get_partition_guid(disk, 1)
    #                         except Exception:
    #                             pass

    #                         if partition_1_guid == BIOS_BOOT_PARTITION_GUID:
    #                             run_command([
    #                                 "chroot", root, "grub-install", "--target=i386-pc", f"/dev/{disk}"
    #                             ])

    #                         # EFI partition: position 2 (SCALE) or 1 (Core migrations)
    #                         efi_partition_number = None
    #                         if partition_1_guid == EFI_SYSTEM_PARTITION_GUID:
    #                             efi_partition_number = 1
    #                         else:
    #                             try:
    #                                 if get_partition_guid(disk, 2) == EFI_SYSTEM_PARTITION_GUID:
    #                                     efi_partition_number = 2
    #                             except Exception:
    #                                 pass

    #                         if efi_partition_number is None:
    #                             continue

    #                         if get_partition_guid(disk, efi_partition_number) != EFI_SYSTEM_PARTITION_GUID:
    #                             continue

    #                     partition = get_partition(disk, efi_partition_number)
    #                     run_command(["chroot", root, "mkdosfs", "-F", "32", "-s", "1", "-n", "EFI", partition])

    #                     run_command(["chroot", root, "mount", "-t", "vfat", partition, "/boot/efi"])
    #                     try:
    #                         grub_cmd = ["chroot", root, "grub-install", "--target=x86_64-efi",
    #                                     "--efi-directory=/boot/efi",
    #                                     "--bootloader-id=debian",
    #                                     "--recheck",
    #                                     "--no-floppy",
    #                                     "--no-nvram"]
    #                         run_command(grub_cmd)

    #                         run_command(["chroot", root, "mkdir", "-p", "/boot/efi/EFI/boot"])
    #                         run_command(["chroot", root, "cp", "/boot/efi/EFI/debian/grubx64.efi",
    #                                      "/boot/efi/EFI/boot/bootx64.efi"])

    #                         if os.path.exists("/sys/firmware/efi"):
    #                             run_command(["chroot", root, "efibootmgr", "-c",
    #                                          "-d", f"/dev/{disk}",
    #                                          "-p", f"{efi_partition_number}",
    #                                          "-L", f"TrueNAS-{i}",
    #                                          "-l", "/EFI/debian/grubx64.efi"])
    #                     finally:
    #                         run_command(["chroot", root, "umount", "/boot/efi"])
    #             else:
    #                 write_progress(0.96, "No need to update grub in ESP")
    #         finally:
    #             logger.debug("finally!")
    #             for cmd in reversed(undo):
    #                 run_command(cmd)

    #             run_command(["umount", root])
    #     logger.debug("before TRUENAS_DATASETS!")
    #     for entry in TRUENAS_DATASETS:
    #         logger.debug("TRUENAS_DATASETS!")
    #         this_ds = f"{dataset_name}/{entry['name']}"
    #         mp = entry.get('mountpoint') or f"/{entry['name']}"
    #         ro = "on" if "RO" in entry["options"] else "off"
    #         run_command(["zfs", "set", f"readonly={ro}", this_ds])

    #         if entry.get("snap", False):
    #             # Do not create `pristine` snapshot for cloned datasets as this will cause snapshot name conflicts
    #             # when promoting the clone.
    #             if entry["name"] not in cloned_datasets:
    #                 run_command(["zfs", "snapshot", f"{this_ds}@pristine"])

    #         run_command(["zfs", "set", f"mountpoint={mp}", this_ds])
    #         run_command(["zfs", "set", 'org.zectl:bootloader=""', this_ds])

    #     logger.debug("before zfs set!")
    #     run_command(["zfs", "set", "readonly=on", dataset_name])
    #     run_command(["zfs", "snapshot", f"{dataset_name}@pristine"])
    #     logger.debug("after zfs set! success!")
    # except Exception:
    #     if old_bootfs_prop != "-":
    #         run_command(["zpool", "set", f"bootfs={old_bootfs_prop}", pool_name])
    #     if cleanup:
    #         run_command(["zfs", "destroy", "-r", dataset_name])
    #     raise

    # configure_system_for_zectl(pool_name)
    write_progress(1.0, _("installation_completed") if is_fresh_install else _("upgrade_completed"))


def check_mountpoint(path):
    try:
        # 预检查路径是否存在，防止无效路径混淆日志
        if not os.path.exists(path):
            logger.warning(f"Check failed: Path '{path}' does not exist.")
            return False

        # 方案 A: 保持使用 mountpoint 工具 (对 ZFS 挂载点检测非常精准)
        result = run_command(["mountpoint", "-q", path])
        is_mounted = result.returncode == 0
        
        # 方案 B: (可选) 使用 Python 原生方法，减少系统调用开销
        # is_mounted = os.path.ismount(path)

        logger.info(f"Path '{path}' is mountpoint: {is_mounted}")
        return is_mounted
    except Exception as e:
        logger.error(f"Error checking mountpoint for '{path}': {e}")
        return False

def check_mountpoint_chroot(path, rpath):
    try:
        full_path = os.path.join(rpath, path.lstrip('/'))
        if not os.path.exists(full_path):
            logger.warning(f"Check failed: Path '{rpath}', '{path}', '{full_path}' does not exist.")
            return False

        result = run_command(["chroot", rpath, "mountpoint", "-q", path])
        is_mounted = result.returncode == 0

        logger.info(f"Path '{path}' is mountpoint: {is_mounted}")
        return is_mounted
    except Exception as e:
        logger.error(f"Error checking mountpoint for '{path}': {e}")
        return False      
              
if __name__ == "__main__":
    main()
