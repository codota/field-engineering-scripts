# Scripts

This is a repository of useful scripts for managing the chat models for your Tabnine Enterprise installation.
<br><br>
### Notes
Use of these scripts may require [curl](https://curl.se/download.html) and [jq](https://jqlang.org/download/).
<br><br>
#### set\_team\_models.sh
A script to set the available chat models on a team-by-team basis.

```
Usage: set_team_models.sh [required] [optional]

  Required:
    --id-token <string>          ID token                        example: eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXV...
    --model-id <string>          Model IDs, comma separated      example: 1,2,3

        Name                       ID
        -----------------------------
        Claude 3.5 Sonnet          0
        Claude 3.7 Sonnet          1
        Claude 4 Sonnet            2
        Claude 4.5 Haiku           3
        Claude 4.5 Sonnet          4
        DeepSeek                   5
        Gemini 2.0 Flash           6
        Gemini 2.5 Flash           7
        Gemini 2.5 Pro             8
        Gemma 3 27B                9
        GPT-4.1                    10
        GPT-4o                     11
        GPT-5                      12
        GPT-OSS                    13
        Llama 3.1 405B             14
        Llama 3.1 70B              15
        Llama 3.3 70B              16
        Mistral 7B                 17
        Qwen                       18
        Tabnine Protected          19

    --team-name <string>         Team name                       example: Tabnine Team (case sensitive)
                                                                          Use "default" for the default team

    --url <string>               Server URL                      example: https://tabnine.com

  Optional:
    --reset                                                      reset team models```
```

```
Example:

  set_team_models.sh \
    --id-token eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXV... \
    --model-id 4,9,18 \
    --team-name "Tabnine Team" \
    --url "https://tabnine.com"
```
