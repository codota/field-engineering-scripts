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
        Claude 4.6 Opus            7
        Claude 4.6 Sonnet          8
        Codestral                  9
        DeepSeek                   10
        Devstral 2                 11
        Devstral 24B               12
        Gemini 2.0 Flash           13
        Gemini 2.5 Flash           14
        Gemini 2.5 Pro             15
        Gemini 3 Pro               16
        Gemma 3 27B                17
        GLM 4.7                    18
        GPT-4                      19
        GPT-4.1                    20
        GPT-4o                     21
        GPT-4o mini                22
        GPT-5                      23
        GPT-5.2                    24
        GPT-5.2 Codex              25
        GPT-5.3 Codex              26
        GPT-OSS                    27
        Llama 3.1 405B             28
        Llama 3.1 70B              29
        Llama 3.3 70B              30
        MiniMax 2.5                31
        MiniMax M2 230B            32
        Mistral                    33
        Mistral 7B                 34
        Qwen                       35
        Qwen Coder 3 30B           36
        Tabnine Protected          37

    --team-name <string>         Team name                       example: Tabnine Team (case sensitive)
                                                                 Use "default" for the default team

    --token <string>             Token                           example: t9u_tkvKUciAHfULXhfdDKBBUNvWt5g...
    --url <string>               Server URL                      example: https://tabnine.com

  Optional:
    --reset                      Reset team models
```

```
Example:

  set_team_models.sh \
    --model-id 6,19,26 \
    --team-name "Tabnine Team" \
    --token t9u_tkvKUciAHfULXhfdDKBBUNvWt5g... \
    --url "https://tabnine.com"
```
