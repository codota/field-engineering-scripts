# Scripts

This is a repository of useful scripts for managing model quotas for your Tabnine Enterprise installation.
<br><br>
### Notes
Use of these scripts may require [curl](https://curl.se/download.html) and [jq](https://jqlang.org/download/).
<br><br>

#### create\_model.sh
A script to create a model quota configuration.

```
Usage: create_model.sh [required] [optional]

  Required:
    --cache-read-cost <float>      Cache read cost per token       example: 0.0000005
    --cache-write-cost <float>     Cache write cost per token      example: 0.00001
    --id-token <string>            ID token                        example: eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXV...
    --input-cost <float>           Input cost per token            example: 0.000005
    --model-id <int>               Model ID                        example: 0

        Name                 ID
        -----------------------
        Claude 4.5 Opus      0
        Devstral 24B         1
        MiniMax M2 230B      2

    --output-cost                  Output cost per token           example: 0.000025
    --url <string>                 Server URL                      example: https://tabnine.com

  Optional:
    --is-active <bool>             true or false                   default: true
```

```
Example:

  create_model.sh \
    --id-token ${JWT} \
    --model-id 0 \
    --cache-read-cost 0.0000005 \
    --cache-write-cost 0.00001 \
    --input-cost 0.000005 \
    --output-cost 0.000025 \
    --url "https://tabnine.com"
```

#### delete\_model.sh
A script to delete a model quota configuration.

```
Usage: delete_model.sh [required]

  Required:
    --id-token <string>            ID token                        example: eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXV...
    --model-id <int>               Model ID                        example: 3

        Name                 ID
        -----------------------
        Claude 3.7 Sonnet    0
        Claude 4 Sonnet      1
        Claude 4.5 Haiku     2
        Claude 4.5 Opus      3
        Claude 4.5 Sonnet    4
        Devstral 24B         5
        Gemini 2.5 Flash     6
        Gemini 2.5 Pro       7
        Gemini 3 Pro         8
        GPT-4.1              9
        GPT-4o               10
        GPT-5                11
        GPT-5.2              12
        GPT-OSS              13
        MiniMax M2 230B      14

    --url <string>                 Server URL                      example: https://tabnine.com
```

```
Example:

  delete_model.sh \
    --id-token ${JWT} \
    --model-id 3 \
    --url "https://tabnine.com"
```

#### fallback\_model.sh
A script to set an agent fallback model.

```
Usage: fallback_model.sh [required]

  Required:
    --id-token <string>            ID token                        example: eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXV...
    --model-id <int>               Model ID                        example: 3

        Name                 ID
        -----------------------
        Claude 3.7 Sonnet    0
        Claude 4 Sonnet      1
        Claude 4.5 Haiku     2
        Claude 4.5 Opus      3
        Claude 4.5 Sonnet    4
        Devstral 24B         5
        Gemini 2.5 Flash     6
        Gemini 2.5 Pro       7
        Gemini 3 Pro         8
        GPT-4.1              9
        GPT-4o               10
        GPT-5                11
        GPT-5.2              12
        GPT-OSS              13
        MiniMax M2 230B      14

    --url <string>                 Server URL                      example: https://tabnine.com
```

```
Example:

  fallback_model.sh \
    --id-token ${JWT} \
    --model-id 3 \
    --url "https://tabnine.com"
```

#### get\_models.sh
A script to get model quota configurations.

```
Usage: get_models.sh [required] [optional]

  Required:
    --id-token <string>          ID token        example: eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXV...
    --url <string>               Server URL      example: https://tabnine.com

  Optional:
    --active                     Show only active models
```

```
Example:

  get_models.sh \
    --id-token eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXV... \
    --url "https://tabnine.com"
```

#### update\_model.sh
A script to update a model quota configuration.

```
Usage: update_model.sh [required] [optional]

  Required:
    --cache-read-cost <float>      Cache read cost per token       example: 0.0000005
    --cache-write-cost <float>     Cache write cost per token      example: 0.00001
    --id-token <string>            ID token                        example: eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXV...
    --input-cost <float>           Input cost per token            example: 0.000005
    --model-id <int>               Model ID                        example: 3

        Name                 ID
        -----------------------
        Claude 3.7 Sonnet    0
        Claude 4 Sonnet      1
        Claude 4.5 Haiku     2
        Claude 4.5 Opus      3
        Claude 4.5 Sonnet    4
        Devstral 24B         5
        Gemini 2.5 Flash     6
        Gemini 2.5 Pro       7
        Gemini 3 Pro         8
        GPT-4.1              9
        GPT-4o               10
        GPT-5                11
        GPT-5.2              12
        GPT-OSS              13
        MiniMax M2 230B      14

    --output-cost                  Output cost per token           example: 0.000025
    --url <string>                 Server URL                      example: https://tabnine.com

  Optional:
    --is-active <bool>             true or false                   default: true
```

```
Example:

  update_model.sh \
    --id-token ${JWT} \
    --model-id 0 \
    --cache-read-cost 0.0000005 \
    --cache-write-cost 0.00001 \
    --input-cost 0.000005 \
    --output-cost 0.000025 \
    --url "https://tabnine.com"
```