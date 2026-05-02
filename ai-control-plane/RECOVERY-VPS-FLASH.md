# RECOVERY: VPS Flash je DOWN (2026-05-02)

## Co se stalo
2026-05-02 ~20:40 ecosystem_health_check.sh detekoval `VPS OFFLINE`.

Diagnostika z Macu:
- `ping 1.1.1.1` → OK (Mac internet funkční)
- `ping 173.212.220.67` (Flash public IP) → 100% packet loss
- `ssh root@10.77.0.1` → timeout (přes WG)
- `ssh root@173.212.220.67` → timeout (přes public)
- `traceroute` se zastaví na backbone Frankfurt (ffm-bb1-link.ip.twelve99.net) — paket nedoteče do Contabo DC Nuremberg

## Hypotéza
Provider-side issue (Contabo outage / kernel panic / hardware) NEBO firewall/UFW config issue na VPS samotném.

## Recovery — ~2 minuty Filipova UI

### Krok 1: Otevři Contabo panel
URL: **https://my.contabo.com/login**
Login: dopita@oneflow.cz
Heslo: jsi jediný kdo má (bylo jen na VPS v master.env, kterou teď nedostaneš)

### Krok 2: Najdi Flash instance
Customer ID: **14766884**
Instance ID: **203170453**
Cesta v UI: `Your Services → VPS / Cloud VPS → vmd103170` (nebo dle aktuálního názvu)

### Krok 3: Zkontroluj status
- Pokud je status `Running` ale ssh nejede → Krok 4 (restart)
- Pokud je status `Stopped` → tlačítko `Start`
- Pokud je status `Error` → kontaktuj Contabo support (rare)

### Krok 4: Restart
- Nejdřív zkus **Soft Restart** (graceful shutdown + start)
- Pokud nereaguje za 60s → **Hard Restart** (force power cycle)

### Krok 5: Po restartu (počkej 60-90s) ověř z Macu
```bash
ping -c 3 173.212.220.67
ssh -o ConnectTimeout=8 root@173.212.220.67 "uptime; systemctl status wg-quick@wg0 sshd hermes conductor"
```

### Krok 6: Pokud ssh přes public funguje ale WG ne
```bash
ssh root@173.212.220.67 "systemctl restart wg-quick@wg0; sleep 3; ip a show wg0"
ssh root@10.77.0.1 "echo WG_RESTORED"  # tunel by měl být zpět
```

### Krok 7: Po recovery → ntfy mě
Filip pošle "VPS up" do chatu, nebo:
```bash
curl -d "VPS Flash up after recovery" https://ntfy.oneflow.cz/Filip
```

## Po recovery action items (Claude Code automated)
Až bude VPS up, automaticky proběhne:
1. ecosystem_health_check.sh self-heal (Mutagen resume, WG check)
2. Conductor restart pokud je potřeba
3. Hermes daemon check
4. Continuation toho ekosystem-task který Filip zadal

## Prevention — co opravím Mac-side bez VPS
- ecosystem_health_check.sh má bug: testuje starou Alfa IP (89.221.212.203, discontinued 2026-04-12). **Bude opraveno** — substitute s 173.212.220.67 (Flash public).
- Mac swap pressure 88% — diagnostika a doporučení.
- Crash-looping com.dopita.claude-auth-sync — investigovat a fixnout.
