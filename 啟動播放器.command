#!/bin/bash
# 音樂播放器啟動腳本 - 雙擊即可使用
DIR="$(cd "$(dirname "$0")" && pwd)"
PORT=8765

echo "🎵 啟動音樂播放器..."

# 如果已在執行，直接開啟
if lsof -ti:$PORT > /dev/null 2>&1; then
    open -a "Google Chrome" "http://127.0.0.1:$PORT/%E9%9F%B3%E6%A8%82%E6%92%AD%E6%94%BE%E5%99%A8.html"
    echo "✓ 播放器已在執行中，開啟瀏覽器"
    exit 0
fi

# 啟動本地伺服器（COOP/COEP + yt-dlp 下載路由）
python3 - "$DIR" "$PORT" << 'PYEOF' &
import http.server, os, sys, socketserver
from urllib.parse import urlparse, parse_qs, quote

class COIHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(204)
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == '/ytdl':
            self._ytdl(parse_qs(parsed.query))
        elif parsed.path == '/open-downloads':
            import subprocess
            subprocess.Popen(['open', os.path.expanduser('~/Downloads')])
            self.send_response(204)
            self.end_headers()
        else:
            super().do_GET()

    def _ytdl(self, params):
        url = (params.get('url') or [None])[0]
        if not url:
            self._err(400, 'Missing url parameter')
            return

        import subprocess, tempfile, shutil, shutil as _sh

        # 自動尋找 yt-dlp（兼容各種安裝位置）
        def find_ytdlp():
            import shutil as sh
            # 先用 which
            p = sh.which('yt-dlp')
            if p: return p
            # 常見安裝位置
            candidates = [
                os.path.expanduser('~/Library/Python/3.9/bin/yt-dlp'),
                os.path.expanduser('~/Library/Python/3.10/bin/yt-dlp'),
                os.path.expanduser('~/Library/Python/3.11/bin/yt-dlp'),
                os.path.expanduser('~/.local/bin/yt-dlp'),
                '/opt/homebrew/bin/yt-dlp',
                '/usr/local/bin/yt-dlp',
            ]
            for c in candidates:
                if os.path.isfile(c): return c
            return None

        ytdlp = find_ytdlp()
        if not ytdlp:
            self._err(503, 'yt-dlp 未安裝。請執行: pip3 install yt-dlp')
            return

        def find_ffmpeg():
            import shutil as sh
            p = sh.which('ffmpeg')
            if p: return p
            for c in ['/opt/homebrew/bin/ffmpeg', '/usr/local/bin/ffmpeg']:
                if os.path.isfile(c): return c
            return None

        ffmpeg = find_ffmpeg()

        # 先下載到暫存資料夾，成功再移到 ~/Downloads
        tmpdir = tempfile.mkdtemp()
        out_tmpl = os.path.join(tmpdir, '%(title)s.%(ext)s')
        cmd = [ytdlp, '-x', '--audio-format', 'mp3', '--audio-quality', '0',
               '--no-playlist', '--no-warnings', '-o', out_tmpl]
        if ffmpeg:
            cmd += ['--ffmpeg-location', ffmpeg]
        cmd.append(url)
        r = subprocess.run(cmd, capture_output=True, timeout=300)
        files = [f for f in os.listdir(tmpdir) if f.endswith('.mp3')]
        if not files:
            self._err(500, 'Download failed: ' + r.stderr.decode(errors='replace')[:200])
            shutil.rmtree(tmpdir, ignore_errors=True)
            return

        fname = files[0]
        src = os.path.join(tmpdir, fname)

        # 移到 ~/Downloads
        dl_dir = os.path.expanduser('~/Downloads')
        dst = os.path.join(dl_dir, fname)
        shutil.move(src, dst)
        shutil.rmtree(tmpdir, ignore_errors=True)

        # 在 Finder 中顯示檔案
        subprocess.Popen(['open', '-R', dst])

        with open(dst, 'rb') as f:
            data = f.read()

        encoded_name = quote(fname, safe='')
        self.send_response(200)
        self.send_header('Content-Type', 'audio/mpeg')
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Content-Disposition', f"attachment; filename*=UTF-8''{encoded_name}")
        self.end_headers()
        self.wfile.write(data)

    def _err(self, code, msg):
        body = msg.encode()
        self.send_response(code)
        self.send_header('Content-Type', 'text/plain; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass

os.chdir(sys.argv[1])
port = int(sys.argv[2])
with socketserver.TCPServer(('127.0.0.1', port), COIHandler) as httpd:
    httpd.serve_forever()
PYEOF

sleep 1

# 開啟 Chrome（若無 Chrome 則用預設瀏覽器）
URL="http://127.0.0.1:$PORT/%E9%9F%B3%E6%A8%82%E6%92%AD%E6%94%BE%E5%99%A8.html"
if [ -d "/Applications/Google Chrome.app" ]; then
    open -a "Google Chrome" "$URL"
else
    open "$URL"
fi

echo "✓ 播放器已啟動！請保持這個視窗開啟。"
echo "  YouTube 下載功能需安裝 yt-dlp："
echo "  pip3 install yt-dlp"
echo ""
echo "按 Ctrl+C 可關閉伺服器。"
wait
