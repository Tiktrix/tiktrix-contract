# TikTrix Contract

## Overview

TikTrix is a Web3-based HTML5 game participation platform.

## Key Features

### Game Management

- Creators can create and manage new game challenges.
- Set game rules and challenge fees.

### Gameplay and Score Processing

- Store users' game participation records.
- Calculate scores and manage ranking systems.
- Validate and record game results.

### Game Challenge Participation

- Process applications from fans for game participation.
- Handle entry fee payments.

### Game Challenge Rewards

- Select winners and distribute rewards.
- Allocate earnings to creators.

### 1. Install ThirdWeb CLI

```bash
npx thirdweb install
```

### 2. Install Dependencies

```bash
yarn install
# or
npm install
```

### 3. Configure API Key

1. Obtain your API key from the ThirdWeb dashboard
2. Set up your API key as an environment variable:

```bash
echo 'export THIRDWEB_API_KEY="your_api_key_here"' >> ~/.zshrc
source ~/.zshrc
```

### 4. Deploy Contract

```bash
yarn contract ./contract/{folder_name}
```

> 💡 **Important Notes**
>
> - Keep your API key secure and never share it
> - Restart your terminal or run `source ~/.zshrc` after setting environment variables
> - Verify all configurations before deploying your contract
