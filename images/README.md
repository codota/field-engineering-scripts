# Scripts

This is a repository of useful scripts for managing the container images for your Tabnine Enterprise installation.<br><br>
### Notes
Use of these scripts may require [docker](https://docs.docker.com/engine/install/), [helm](https://helm.sh/docs/intro/install/), and [yq](https://github.com/mikefarah/yq).
<br><br>
#### download\_and\_push.sh
A script to download the required container images and push them to a private registry.

```
Usage: download_and_push.sh [required] [optional]

  Required:
    --registry <string>        Target registry hostname            example: docker.io
    --values <path>            Helm Chart values file              example: ./values.yaml

  Optional:
    --attribution              Enable Attribution
    --chart <path|url>         Path to Helm Chart                  default: oci://registry.tabnine.com/self-hosted/tabnine-cloud
    --cleanup                  Delete downloaded images
    --dry-run                  Print docker commands
    --help                     Display help
    --keda                     Enable KEDA
    --version <string>         Helm chart version                  default: latest
    --vllm                     Enable vLLM
    --vllm-online <bool>       vLLM Internet access enabled        default: false
```

```
Example:

  download_and_push.sh \
    --attribution \
    --cleanup \
    --keda \
    --registry docker.io \
    --values ./values.yaml \
    --version 6.2.0 \
    --vllm \
    --vllm-online true
```

#### download\_and\_save.sh
A script to download the required container images and save to your local disk. Useful for transfering the container images to an air-gapped environment.

```
Usage: download_and_save.sh [required] [optional]

  Required:
    --output <path>            Save images to specified path       example: ./images
    --values <path>            Helm Chart values file              example: ./values.yaml

  Optional:
    --attribution              Enable Attribution
    --chart <path|url>         Path to Helm Chart                  default: oci://registry.tabnine.com/self-hosted/tabnine-cloud
    --cleanup                  Delete downloaded images
    --dry-run                  Print docker commands
    --help                     Display help
    --keda                     Enable KEDA
    --version <string>         Helm chart version                  default: latest
    --vllm                     Enable vLLM
    --vllm-online <bool>       vLLM Internet access enabled        default: false
```

```
Example:

  download_and_save.sh \
    --attribution \
    --cleanup \
    --keda \
    --output ./images \
    --values ./values.yaml \
    --version 6.2.0 \
    --vllm \
    --vllm-online true
```

#### generate\_image\_list.sh
A script to generate a list of images required for a specific release.

```
Usage: generate_image_list.sh [required] [optional]

  Required:
    --output <path>          Write image list to disk        example: ./images.txt
    --values <path>          Helm Chart values file          example: ./values.yaml

  Optional:
    --attribution            Enable Attribution
    --chart <path|url>       Path to Helm Chart              default: oci://registry.tabnine.com/self-hosted/tabnine-cloud
    --help                   Display help
    --keda                   Enable KEDA
    --version <string>       Helm Chart version              default: latest
    --vllm                   Enable vLLM
    --vllm-online <bool>     vLLM Internet access enabled    default: false
```
```
Example:

  generate_image_list.sh \
    --attribution \
    --output ./images.txt \
    --keda \
    --values ./values.yaml \
    --version 6.2.0 \
    --vllm \
    --vllm-online true
```