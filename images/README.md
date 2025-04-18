# Scripts

This is a repository of useful scripts for managing the container images for your Tabnine Enterprise installation.<br><br>
### Notes
Use of these scripts may require [docker](https://docs.docker.com/engine/install/), [helm](https://helm.sh/docs/intro/install/), and [yq](https://github.com/mikefarah/yq).
<br><br>
#### generate\_image\_list.sh
A script to generate a list of images required for a specific release.

```
Usage: generate_image_list.sh [required] [options]

  Required:
    --values <file>                        Helm Chart values file              example: ./values.yaml

  Options:
    --all                                  All container images
    --attribution-chart <file|path|url>    Helm Chart location                 default: oci://registry.tabnine.com/self-hosted/tabnine-attribution-db
    --attribution-lookup                   Enable local attribution lookup
    --attribution-values <file>            Helm Chart values file              example: ./values.yaml
    --chart <file|path|url>                Helm Chart location                 default: oci://registry.tabnine.com/self-hosted/tabnine-cloud
    --external-chat                        External chat models only
    --output <file>                        Write output to a file              default: ./images.list
    --version <string>                     Helm Chart version                  default: latest
```

```
Example:

  generate_image_list.sh \
    --values ./values.yaml \
    --attribution-lookup \
    --attribution-values ./values-attribution.yaml \
    --output /var/tmp/images.txt \
    --version x.x.x
```

#### download\_and\_push.sh
A script to download the required container images and push them to a private registry.

```
Usage: download_and_push.sh [required] [options]

  Required:
    --registry <string>                    Target registry hostname                example: docker.io

  Options:
    --all                                  All container images
    --attribution-chart <file|path|url>    Helm chart location                     default: oci://registry.tabnine.com/self-hosted/tabnine-attribution-db
    --attribution-lookup                   Enable local attribution lookup
    --attribution-values <file>            Helm chart values file                  example: ./values.yaml
    --chart <file|path|url>                Helm chart location                     default: oci://registry.tabnine.com/self-hosted/tabnine-cloud
    --cleanup                              Delete downloaded images
    --dry-run                              Print docker commands
    --ecr                                  Print ECR repository names
    --external-chat                        External chat models only
    --list <file>                          List of images
    --repo <string>                        Target registry repository for --list   default: tabnine
    --values <file>                        Helm chart values file
    --version <string>                     Helm chart version                      default: latest
```

```
Example:

  download_and_push.sh \
    --registry docker.io \
    --values ./values.yaml \
    --attribution-lookup \
    --attribution-values ./values-attribution.yaml \
    --version x.x.x \
    --cleanup
```

#### download\_and\_save.sh
A script to download the required container images and save to your local disk. Useful for transfering the container images to an air-gapped environment.

```
Usage: download_and_save.sh [options]

  Options:
    --all                                  All container images
    --attribution-chart <file|path|url>    Helm chart location                 default: oci://registry.tabnine.com/self-hosted/tabnine-attribution-db
    --attribution-lookup                   Enable local attribution lookup
    --attribution-values <file>            Helm chart values file              example: ./values.yaml
    --chart <file|path|url>                Helm chart location                 default: oci://registry.tabnine.com/self-hosted/tabnine-cloud
    --cleanup                              Delete downloaded images
    --dry-run                              Print docker commands
    --external-chat                        External chat models only
    --list <file>                          List of images                      example: ./images.txt
    --output <path>                        Write images to specifc path        default: ./
    --values <file>                        Helm chart values file              example: ./values.yaml
    --version <string>                     Helm chart version                  default: latest
```

```
Example:

  download_and_save.sh \
    --values ./values.yaml \
    --attribution-lookup \
    --attribution-values ./values-attribution.yaml \
    --version x.x.x \
    --output /var/tmp \
    --cleanup
```