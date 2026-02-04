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
        Claude 3.5 Sonnet v2       1
        Claude 3.7 Sonnet          2
        Claude 4 Sonnet            3
        Claude 4.5 Haiku           4
        Claude 4.5 Opus            5
        Claude 4.5 Sonnet          6
        DeepSeek                   7
        Devstral 24B               8
        Gemini 2.0 Flash           9
        Gemini 2.5 Flash           10
        Gemini 2.5 Pro             11
        Gemini 3 Pro               12
        Gemma 3 27B                13
        GPT-4                      14
        GPT-4.1                    15
        GPT-4o                     16
        GPT-4o mini                17
        GPT-5                      18
        GPT-5.2                    19
        GPT-OSS                    20
        Llama 3.1 405B             21
        Llama 3.1 70B              22
        Llama 3.3 70B              23
        MiniMax M2 230B            24
        Mistral 7B                 25
        Qwen                       26
        Qwen Coder 3 30B           27
        Tabnine Protected          28

    --team-name <string>         Team name                       example: Tabnine Team (case sensitive)
                                                                 Use "default" for the default team

    --url <string>               Server URL                      example: https://tabnine.com

  Optional:
    --reset                      Reset team models
```

```
Example:

  set_team_models.sh \
    --id-token eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXV... \
    --model-id 6,19,26 \
    --team-name "Tabnine Team" \
    --url "https://tabnine.com"
```

#### use\_hidden\_models.sh
A script to enable models that are hidden by default.

```
Usage: use_hidden_models.sh [required] [optional]

  Required:
    --id-token <string>          ID token                        example: eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXV...
    --model-id <string>          Model IDs, comma separated      example: 1,2,3

        Name                       ID
        -----------------------------
        Claude 4.5 Opus            0
        DeepSeek                   1
        Devstral 24B               2
        MiniMax M2 230B            3

    --url <string>               Server URL                      example: https://tabnine.com

  Optional:
    --reset                      Reset hidden models
```

```
Example:

  use_hidden_models \
    --id-token eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXV... \
    --model-id 0,2 \
    --url "https://tabnine.com"
```