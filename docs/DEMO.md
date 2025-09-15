# Demo Walkthrough

1) **SSH into web-vm** and start a simple HTTP server:

```bash
python3 -m http.server 8080
```

2) **SSH into app-vm** and test access to web-vm on port 8080:

```bash
curl http://<web-vm-private-ip>:8080
```

3) **Verify isolation**: attempt `app -> db` and confirm it's **denied** per NSG/ASG policy.

4) **Generate CPU load** on `db-vm` (e.g., `stress-ng`) to trigger the sample CPU alert (>60%).

5) **Review metrics & logs** in Azure Monitor and Log Analytics. See `monitoring/kql` for handy queries.
