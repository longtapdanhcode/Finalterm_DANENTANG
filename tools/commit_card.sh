#!/usr/bin/env bash
# ==============================================================================
# Lấy commit cho 1 Card theo phân công Sprint.
#
# Cách dùng (chạy từ bất kỳ đâu trong repo nhóm):
#   tools/commit_card.sh --card <N> --tv <K> [--src <repo test>] [--yes] [--allow-secrets]
#
#   --card N          Số Card (1-13), ứng với tools/cards/cardNN.txt
#   --tv K            Số thứ tự thành viên (1, 2, 3) - dùng đặt tên nhánh
#   --src DIR         Thư mục repo test chứa code đã build sẵn. Script chép đúng
#                     các file của Card từ đây vào repo nhóm. Bỏ qua nếu file đã
#                     nằm sẵn trong repo nhóm.
#   --yes             Không hỏi xác nhận trước khi commit/push
#   --allow-secrets   Bỏ qua chặn khi phát hiện chuỗi giống khóa bí mật
#
# Script KHÔNG xóa .git, KHÔNG force push, KHÔNG đổi git user.name/email.
# Tương thích bash 3.2 (macOS mặc định).
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; CYAN=$'\033[0;36m'; NC=$'\033[0m'

BRANCH=""
BRANCH_CREATED=0

die() {
  echo "${RED}[x] $*${NC}" >&2
  if [ "$BRANCH_CREATED" -eq 1 ]; then
    echo "${YELLOW}    Để làm lại từ đầu:${NC} git reset -q && git checkout develop && git branch -D $BRANCH" >&2
    echo "${YELLOW}    (file đã chép vào cây thư mục vẫn còn; file mới là untracked, file cũ bị sửa xem bằng git status)${NC}" >&2
  fi
  exit 1
}
info() { echo "${CYAN}==> $*${NC}"; }
ok()   { echo "${GREEN}[✓] $*${NC}"; }
warn() { echo "${YELLOW}[!] $*${NC}"; }

usage() { sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

# ---------------------------------------------------------------- tham số
card=""; tv=""; src=""; assume_yes=0; allow_secrets=0
while [ $# -gt 0 ]; do
  case "$1" in
    --card) [ $# -ge 2 ] || die "--card thiếu giá trị"; card="$2"; shift 2 ;;
    --tv)   [ $# -ge 2 ] || die "--tv thiếu giá trị";   tv="$2";   shift 2 ;;
    --src)  [ $# -ge 2 ] || die "--src thiếu giá trị";  src="$2";  shift 2 ;;
    --yes|-y) assume_yes=1; shift ;;
    --allow-secrets) allow_secrets=1; shift ;;
    -h|--help) usage 0 ;;
    *) die "Tham số không hợp lệ: $1 (xem --help)" ;;
  esac
done

case "$card" in ''|*[!0-9]*) die "--card phải là số, ví dụ --card 5" ;; esac
case "$tv"   in ''|*[!0-9]*) die "--tv phải là số, ví dụ --tv 1" ;; esac
card=$((10#$card)); tv=$((10#$tv))

card_file="$SCRIPT_DIR/cards/card$(printf '%02d' "$card").txt"
[ -f "$card_file" ] || die "Không thấy $card_file"

# ---------------------------------------------------------------- đọc danh sách Card
meta() { sed -n "s/^#$1=//p" "$card_file" | head -n 1; }
sprint="$(meta sprint)"; msg="$(meta msg)"; needs="$(meta needs)"
[ -n "$sprint" ] && [ -n "$msg" ] || die "$card_file thiếu #sprint= hoặc #msg="

# Mỗi dòng file: "path" (bắt buộc) hoặc "?path" (tùy chọn, bỏ qua nếu thiếu)
req_files=(); opt_files=()
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  case "$line" in ''|'#'*) continue ;; esac
  optional=0
  case "$line" in '?'*) optional=1; line="${line#\?}" ;; esac
  case "$line" in
    /*|*..*) die "Đường dẫn không hợp lệ trong $card_file: $line" ;;
  esac
  if [ "$optional" -eq 1 ]; then opt_files+=("$line"); else req_files+=("$line"); fi
done < "$card_file"
[ "${#req_files[@]}" -gt 0 ] || die "$card_file không có file nào"

BRANCH="feature/sprint${sprint}-card${card}-tv${tv}"

# ---------------------------------------------------------------- kiểm tra repo
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Không nằm trong git repo"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

[ -n "$(git config user.name || true)" ] && [ -n "$(git config user.email || true)" ] \
  || die "Chưa cấu hình tên thật: git config user.name \"Ten Ban\" && git config user.email \"email@cua.ban\""
git remote get-url origin >/dev/null 2>&1 || die "Repo chưa có remote origin"
git diff --quiet && git diff --cached --quiet \
  || die "Đang có thay đổi chưa commit trên các file đã track. Commit hoặc git stash trước."
git show-ref --verify --quiet "refs/heads/$BRANCH" && die "Nhánh $BRANCH đã tồn tại. Xóa nó hoặc chọn --tv khác."

# ---------------------------------------------------------------- kiểm tra nguồn file
if [ -n "$src" ]; then
  [ -d "$src" ] || die "--src không phải thư mục: $src"
  src="$(cd "$src" && pwd)"
  [ "$src" != "$ROOT" ] || die "--src trùng với repo nhóm, hãy trỏ tới repo test"
  missing=0
  for p in "${req_files[@]}"; do
    if [ ! -e "$src/$p" ]; then echo "${RED}    thiếu trong --src: $p${NC}"; missing=1; fi
  done
  [ "$missing" -eq 0 ] || die "Repo test thiếu file bắt buộc của Card $card (liệt kê ở trên). Chưa đụng gì tới repo nhóm."
fi

# ---------------------------------------------------------------- chuẩn bị nhánh
info "Card $card (Sprint $sprint) → nhánh $BRANCH"
git fetch origin
git show-ref --verify --quiet "refs/remotes/origin/develop" || die "origin chưa có nhánh develop"

if [ -n "$needs" ]; then
  not_merged=""
  for n in $(echo "$needs" | tr ',' ' '); do
    if [ -z "$(git log origin/develop --oneline --grep="Card ${n} -" 2>/dev/null | head -n 1)" ]; then
      not_merged="$not_merged $n"
    fi
  done
  if [ -n "$not_merged" ]; then
    warn "Card $card cần Card:${not_merged} đã merge vào develop, nhưng chưa thấy commit tương ứng."
    warn "(Nếu nhóm squash-merge với tiêu đề PR khác, cảnh báo này có thể sai.)"
    if [ "$assume_yes" -eq 0 ]; then
      read -r -p "Vẫn tiếp tục? (y/N) " a; case "$a" in y|Y) ;; *) die "Đã hủy." ;; esac
    fi
  fi
fi

git checkout develop
git pull --ff-only origin develop
git checkout -b "$BRANCH"
BRANCH_CREATED=1

# ---------------------------------------------------------------- chép file (nếu có --src)
if [ -n "$src" ]; then
  info "Chép file từ $src"
  copy_one() {
    local p="${1%/}"
    if [ -d "$src/$p" ]; then
      mkdir -p "$p"; cp -R "$src/$p/." "$p/"
    else
      mkdir -p "$(dirname "$p")"; cp "$src/$p" "$p"
    fi
  }
  for p in "${req_files[@]}"; do copy_one "$p"; done
  if [ "${#opt_files[@]}" -gt 0 ]; then
    for p in "${opt_files[@]}"; do
      if [ -e "$src/$p" ]; then copy_one "$p"; else warn "Bỏ qua file tùy chọn (không có trong --src): $p"; fi
    done
  fi
fi

# ---------------------------------------------------------------- git add đúng file được giao
add_list=()
for p in "${req_files[@]}"; do
  [ -e "$p" ] || die "Thiếu file bắt buộc trong repo nhóm: $p (dùng --src để chép từ repo test)"
  add_list+=("$p")
done
if [ "${#opt_files[@]}" -gt 0 ]; then
  for p in "${opt_files[@]}"; do [ -e "$p" ] && add_list+=("$p"); done
fi

# Không dùng 'git add .' / '-A': chỉ add từng đường dẫn liệt kê
git add -- "${add_list[@]}" || die "git add lỗi (file có thể bị .gitignore chặn)"

[ -n "$(git diff --cached --name-only)" ] \
  || die "Không có thay đổi nào để commit: file của Card $card đã giống hệt develop."

echo
git status --short
echo
git diff --cached --stat | tail -n 1

# Chỉ được staged đúng file thuộc Card
unexpected=""
while IFS= read -r f; do
  hit=0
  for p in "${add_list[@]}"; do
    pp="${p%/}"
    case "$f" in "$pp"|"$pp"/*) hit=1; break ;; esac
  done
  [ "$hit" -eq 1 ] || unexpected="$unexpected\n    $f"
done < <(git diff --cached --name-only)
[ -z "$unexpected" ] || die "Có file ngoài danh sách Card đang staged:$(printf "$unexpected")"

# ---------------------------------------------------------------- quét khóa bí mật
SECRET_RE='eyJ[A-Za-z0-9_-]{20,}|service_role|sb_secret_[A-Za-z0-9_-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16}|sk_live_[0-9A-Za-z]+'
if hits="$(git grep --cached -nIE "$SECRET_RE" -- "${add_list[@]}" 2>/dev/null | cut -d: -f1,2)" && [ -n "$hits" ]; then
  echo "${RED}Phát hiện chuỗi giống khóa/token (chỉ hiện file:dòng):${NC}"
  echo "$hits"
  if [ "$allow_secrets" -eq 0 ]; then
    git reset -q
    die "Đã dừng và bỏ staged. Đưa khóa ra file .env/--dart-define (không commit). Nếu chắc đây là khóa public (vd Supabase anon key) thì chạy lại với --allow-secrets."
  fi
  warn "--allow-secrets: tiếp tục dù có cảnh báo."
fi

# ---------------------------------------------------------------- commit + push
echo
echo "Commit message: ${msg}"
if [ "$assume_yes" -eq 0 ]; then
  read -r -p "Commit và push nhánh $BRANCH? (y/N) " a
  case "$a" in
    y|Y) ;;
    *) git reset -q; die "Đã hủy, bỏ staged. File vẫn nằm trong cây thư mục." ;;
  esac
fi

git commit -m "$msg"
git push -u origin "$BRANCH"
ok "Đã push $BRANCH"

url="$(git remote get-url origin | sed -E 's#^git@github\.com:#https://github.com/#; s#\.git$##')"
echo "Mở Pull Request vào develop:"
echo "  $url/compare/develop...$BRANCH?expand=1"
git checkout develop >/dev/null 2>&1 || true
