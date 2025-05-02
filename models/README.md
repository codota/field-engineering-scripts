# Scripts

This is a repository of useful scripts for managing the chat models for your Tabnine Enterprise installation.
<br><br>
### Notes
Use of these scripts may require [curl](https://curl.se/download.html) and [jq](https://jqlang.org/download/).
<br><br>
#### get\_id\_token.sh
A script to fetch an ID token with your username and password (does not work for SSO).

*Notes:*
- The Organization ID can be found in your Helm Chart values file.
- Your password may require escaping for certain special characters (`\!).

```
Usage: get_id_token.sh [required]

  Required:
    --organization-id <string>     Organization ID     example: ee4b8bd9-1cd4-4c7b-89b0-e1e9a00cf320
    --password <string>            Password            example: Tabnine!23
    --url <string>                 Server URL          example: https://tabnine.com
    --username <string>            Username            example: admin@tabnine.com
```

```
Example:

  get_id_token.sh \
    --organization-id ee4b8bd9-1cd4-4c7b-89b0-e1e9a00cf320 \
    --password 'password123' \
    --url "https://tabnine.com" \
    --username admin@tabnine.com
```

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
        Gemini 2.0 Flash           2
        Gemma 3 27B                3
        GPT-3.5 Turbo              4
        GPT-4 Turbo                5
        GPT-4o                     6
        Llama 3.1 405B             7
        Llama 3.1 70B              8
        Mistral 7B                 9
        Qwen2.5-32B-Instruct       10
        Tabnine Protected          11

    --team-name <string>         Team name                       example: Tabnine Team (case sensitive)
                                                                          Use "default" for the default team

    --url <string>               Server URL                      example: https://tabnine.com

  Optional:
    --reset                                                      reset team models
```

```
Example:

  set_team_models.sh \
    --id-token eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXV... \
    --model-id 4,5,8 \
    --team-name "Tabnine Team" \
    --url "https://tabnine.com"
```
