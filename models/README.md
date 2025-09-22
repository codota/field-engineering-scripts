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
        DeepSeek                   3
        Gemini 2.0 Flash           4
        Gemini 2.5 Flash           5
        Gemini 2.5 Pro             6
        Gemma 3 27B                7
        GPT-4.1                    8
        GPT-4o                     9
        GPT-5                      10
        GPT-OSS                    11
        Llama 3.1 405B             12
        Llama 3.1 70B              13
        Llama 3.3 70B              14
        Mistral 7B                 15
        Qwen                       16
        Tabnine Protected          17

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
    --model-id 2,5,8 \
    --team-name "Tabnine Team" \
    --url "https://tabnine.com"
```
