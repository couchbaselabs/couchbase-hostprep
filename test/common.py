##

import docker
from docker.errors import APIError
from docker.models.containers import Container
from docker import APIClient
from typing import Union
import io
import os
import tarfile
import warnings
import logging

warnings.filterwarnings("ignore")
current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
logging.getLogger("docker").setLevel(logging.WARNING)
logging.getLogger("urllib3").setLevel(logging.WARNING)


def copy_to_container(container_id: Container, src: str, dst: str):
    print(f"Copying {src} to {dst}")
    stream = io.BytesIO()
    with tarfile.open(fileobj=stream, mode='w|') as tar, open(src, 'rb') as file:
        info = tar.gettarinfo(fileobj=file)
        info.name = os.path.basename(src)
        tar.addfile(info, file)

    container_id.put_archive(dst, stream.getvalue())


def copy_dir_to_container(container_id: Container, src_dir: str, dst: str):
    print(f"Copying {src_dir} to {dst}")
    stream = io.BytesIO()
    with tarfile.open(fileobj=stream, mode='w|') as tar:
        name = os.path.basename(src_dir)
        tar.add(src_dir, arcname=name, recursive=True)

    container_id.put_archive(dst, stream.getvalue())


def container_mkdir(container_id: Container, directory: str):
    command = ["mkdir", "-p", directory]
    exit_code, output = container_id.exec_run(command)
    assert exit_code == 0


def start_container(image: str, platform: str = "linux/amd64", volume_mount: str = "/opt") -> Container:
    docker_api = APIClient(base_url='unix://var/run/docker.sock')
    client = docker.from_env()
    client.images.prune()
    client.containers.prune()
    client.networks.prune()
    client.volumes.prune()
    docker_api.prune_builds()

    print(f"Starting {image} container")

    try:
        volume = client.volumes.create(name="pytest-volume", driver="local", driver_opts={"type": "tmpfs", "device": "tmpfs", "o": "size=2048m"})
        container_id = client.containers.run(image,
                                             tty=True,
                                             detach=True,
                                             privileged=True,
                                             platform=platform,
                                             name="pytest",
                                             volumes=[f"{volume.name}:{volume_mount}"],
                                             command=["/usr/sbin/init"]
                                             )
    except docker.errors.APIError as e:
        if e.status_code == 409:
            container_id = client.containers.get('pytest')
        else:
            raise

    print("Container started")
    print("Done.")
    return container_id


def run_in_container(container_id: Container, directory: str, command: Union[str, list[str]]):
    exit_code, output = container_id.exec_run(command, workdir=directory)
    for line in output.split(b'\n'):
        print(line.decode("utf-8"))
    assert exit_code == 0
    print("Done.")


def get_container_id(name: str = "pytest"):
    client = docker.from_env()
    try:
        return client.containers.get(name)
    except docker.errors.NotFound:
        return None


def stop_container(container_id: Container):
    client = docker.from_env()
    print("Stopping container")
    container_id.stop()
    print("Removing test container")
    container_id.remove()
    volume = client.volumes.get("pytest-volume")
    volume.remove()
    print("Done.")
