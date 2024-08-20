#!/usr/bin/env python3

"""
## Building Multi-Architecture Docker Images with Docker Buildx

Follow these steps to build Docker images for multiple architectures using Docker Buildx:

1. **Ensure Docker Buildx is Available**
   - Docker Buildx comes with Docker 19.03+. 
   - Verify with `docker buildx version`.

2. **Create a New Builder Instance**
   - Create and switch to a new Buildx builder instance:
     ```
     docker buildx create --name mybuilder --use
     ```

3. **Start the Builder Instance**
   - Start and inspect the builder instance:
     ```
     docker buildx inspect --bootstrap
     ```

4. **Enable Experimental Features (If Required)**
   - Ensure Docker's experimental features are enabled, either in Docker's settings or by setting `DOCKER_CLI_EXPERIMENTAL=enabled` in your environment.

5. **Build and Push the Image**
   - Build your image for the desired platforms and push to a registry:
     ```
     docker buildx build --platform linux/amd64,linux/arm64 -t yourusername/yourimagename:tag --push .
     ```
   - Replace `yourusername/yourimagename:tag` with your actual image details.

6. **Verify the Image**
   - Verify the built image and its architectures:
     ```
     docker buildx imagetools inspect yourusername/yourimagename:tag
     ```

Note: Switching back to the "default" builder is not necessary unless specifically required for your workflow.

"""

import argparse
import os
import subprocess

ROOT_DIR = os.path.dirname(os.path.realpath(__file__))
BUILDER_NAME = "buildx_builder"


def assert_git_clean():
  try:
    subprocess.check_call("git diff --exit-code > /dev/null", shell=True)
    subprocess.check_call("git diff --cached --exit-code > /dev/null", shell=True)
  except Exception:
    print("!! You must be in a clean git repository !!")
    print("Aborting ...")
    exit(1)


def get_head_rev():
  return subprocess.check_output("git rev-parse --short HEAD", shell=True).decode("utf-8").strip()


def get_image_name(dockerfile: str) -> str:
  # given /path/to/ubuntu_20.04.Dockerfile, image_name = ubuntu_20.04
  return os.path.basename(dockerfile).rsplit('.Dockerfile', 1)[0]


def multi_arch_build(dockerfile: str, push: bool = False, yes: bool = False):
    image_name = get_image_name(dockerfile)
    push_or_load = "push" if push else "load"
    
    build_command = "\n".join([
      f"BUILDKIT_PROGRESS=plain \\",
      f"docker buildx build \\",
      f"  --builder {BUILDER_NAME} \\",
      f"  --platform linux/amd64,linux/arm64 \\",
      f"  --{push_or_load} \\",
      f"  -t {image_name}:{get_head_rev()} \\",
      f"  -t {image_name}:latest \\",
      f"  -f {dockerfile} \\",
      f"  {ROOT_DIR}",
    ])

    print("The following will be built:")
    print(build_command)
    print("")

    if not yes:
      if input("Do you want to continue? (y/n) ") != "y":
        exit(0)
      
    if push:
      subprocess.check_call(f"docker login", shell=True)

    # enable QEMU for arm64 / amd64 emulataion
    subprocess.check_call("docker run --privileged --rm tonistiigi/binfmt --install all", shell=True)

    # Configure the builder
    try:
      subprocess.check_call(f"docker buildx inspect {BUILDER_NAME}", shell=True)
      # builder exists
    except Exception:
       # builder doesn't exist
       subprocess.check_call(f"docker buildx create --name {BUILDER_NAME} --driver docker-container --use", shell=True)
       subprocess.check_call(f"docker buildx inspect {BUILDER_NAME} --bootstrap", shell=True)

    # build the images
    subprocess.check_call(build_command, shell=True)


def main():
  dockerfiles = [os.path.join(ROOT_DIR, f) for f in os.listdir(ROOT_DIR) if f.endswith(".Dockerfile")]
  imagename_to_dockerfile = {get_image_name(dockerfile_path): dockerfile_path for dockerfile_path in dockerfiles}
  
  parser = argparse.ArgumentParser(description="Build script for docker images.")
  parser.add_argument("imagename", choices=list(imagename_to_dockerfile.keys()), help="The dockerfile to build")
  parser.add_argument("--push", action="store_true", help="Push the image to docker hub")
  parser.add_argument("--yes", action="store_true", help="Don't prompt for build confirmation")
  args = parser.parse_args()

  assert_git_clean()
  multi_arch_build(
    dockerfile=imagename_to_dockerfile[args.imagename], 
    push=args.push, 
    yes=args.yes,
  )


if __name__ == "__main__":
  main()
