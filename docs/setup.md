# Setup

One-time setup to connect this client to the FIM server.

## 1. Get credentials from your supervisor

- SSH private key file (e.g. `fim-YOUR_USERNAME`)
- Server IP
- Your username

## 2. Install the key

```bash
cp fim-YOUR_USERNAME ~/.ssh/fim-YOUR_USERNAME
chmod 600 ~/.ssh/fim-YOUR_USERNAME
```

## 3. Create your config

```bash
cp config.yaml.example config.yaml
```

Edit `config.yaml`:

```yaml
user: YOUR_USERNAME
server: YOUR_SERVER_IP
ssh_key: ~/.ssh/fim-YOUR_USERNAME
port: 8765
```

## 4. Test the connection

```bash
ssh -i ~/.ssh/fim-YOUR_USERNAME fim-YOUR_USERNAME@YOUR_SERVER_IP 'fim-run list'
```

If you see a list of commands, you are connected.

## Next

- [Run a campaign](running-campaigns.md)
- [Write a benchmark](writing-benchmarks.md)
