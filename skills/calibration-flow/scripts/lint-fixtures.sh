#!/usr/bin/env bash
# lint-fixtures.sh — integrity linter for behavioural-flow fixture cases.
# Asserts each case has input/ + a parseable expected.md oracle (valid class, severities, signature
# shape, AC statuses). With --catalogue, also checks every oracle signature exists in the catalogue.
# Usage: lint-fixtures.sh [--catalogue <signatures.md>] <case-dir> [case-dir ...]
# Output: path<TAB>signature<TAB>severity<TAB>detail   (a clean fixture emits nothing).
set -euo pipefail
emit() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"; }

catalogue=""
if [ "${1:-}" = "--catalogue" ]; then catalogue="${2:-}"; shift 2; fi

for dir in "$@"; do
  if [ ! -d "$dir" ]; then
    emit "$dir" "flow:fixture-missing-input" HIGH "case directory not found"
    continue
  fi
  [ -d "$dir/input" ] || emit "$dir" "flow:fixture-missing-input" HIGH "no input/ directory"
  exp="$dir/expected.md"
  if [ ! -f "$exp" ]; then
    emit "$dir" "flow:fixture-missing-expected" HIGH "no expected.md oracle"
    continue
  fi

  # awk validates the oracle and prints two line kinds:
  #   ISSUE<TAB>signature<TAB>severity<TAB>detail   — a structural/value problem
  #   FOUNDSIG<TAB>signature                        — a shape-valid signature used in a table
  awk '
    function trim(s){ gsub(/^[[:space:]]+|[[:space:]]+$/,"",s); return s }
    function shaped(s){ return (s ~ /^(flow|handoff|review):[a-z0-9-]+$/) }
    BEGIN{ fm=0; sec=""; fence=0; hdr=0; sawCase=0; sawClass=0; sawPlanted=0; badClass=0 }
    /^---[[:space:]]*$/{ fm++; next }
    fm==1{
      if($0 ~ /^case:/){ sawCase=1 }
      if($0 ~ /^class:/){ sawClass=1; cls=trim(substr($0,index($0,":")+1))
        if(cls!="known-good" && cls!="known-defect" && cls!="adversarial" && cls!="ac-mismatch"){ badClass=1; badc=cls } }
      next
    }
    /^##[[:space:]]+Planted defects/{ sec="planted"; sawPlanted=1; fence=0; hdr=0; next }
    /^##[[:space:]]+Edge contracts/{ sec="edge"; fence=0; hdr=0; next }
    /^##[[:space:]]+Intent acceptance criteria/{ sec="intent"; fence=0; hdr=0; next }
    /^##[[:space:]]/{ sec=""; fence=0; next }
    {
      if(sec!="" && $0 ~ /^[[:space:]]*```/){ fence=(fence==0)?1:0; hdr=0; next }
      if(sec!="" && fence==1){
        if($0 ~ /^[[:space:]]*$/) next
        if(hdr==0){ hdr=1; next }
        n=split($0,c,"\t"); for(x=1;x<=n;x++) c[x]=trim(c[x])
        if(sec=="planted"){
          sig=c[3]; sev=c[4]; must=c[5]
          if(!shaped(sig)) printf "ISSUE\tflow:fixture-unparseable\tHIGH\tplanted signature %s is not <area>:<name>\n", sig
          else printf "FOUNDSIG\t%s\n", sig
          if(sev!="CRITICAL" && sev!="HIGH" && sev!="MEDIUM" && sev!="LOW" && sev!="INFO")
            printf "ISSUE\tflow:fixture-bad-severity\tHIGH\tplanted severity %s not in CRITICAL|HIGH|MEDIUM|LOW|INFO\n", sev
          if(must!="yes" && must!="no")
            printf "ISSUE\tflow:fixture-unparseable\tHIGH\tplanted must_catch %s not yes|no\n", must
        } else if(sec=="edge"){
          sig=c[2]; must=c[3]
          if(!shaped(sig)) printf "ISSUE\tflow:fixture-unparseable\tHIGH\tedge signature %s is not <area>:<name>\n", sig
          else printf "FOUNDSIG\t%s\n", sig
          if(must!="yes" && must!="no")
            printf "ISSUE\tflow:fixture-unparseable\tHIGH\tedge must_hold %s not yes|no\n", must
        } else if(sec=="intent"){
          st=c[2]
          if(st!="met" && st!="partial" && st!="blocked" && st!="unknown")
            printf "ISSUE\tflow:fixture-unparseable\tHIGH\tintent expect_status %s not met|partial|blocked|unknown\n", st
        }
        next
      }
    }
    END{
      if(!sawCase || !sawClass) printf "ISSUE\tflow:fixture-unparseable\tHIGH\tfrontmatter missing case/class\n"
      if(badClass) printf "ISSUE\tflow:fixture-unparseable\tHIGH\tunknown class %s\n", badc
      if(!sawPlanted) printf "ISSUE\tflow:fixture-unparseable\tHIGH\tno \"## Planted defects\" section\n"
    }
  ' "$exp" | while IFS="$(printf '\t')" read -r kind a b c; do
    if [ "$kind" = "ISSUE" ]; then
      emit "$dir" "$a" "$b" "$c"
    elif [ "$kind" = "FOUNDSIG" ] && [ -n "$catalogue" ] && [ -f "$catalogue" ]; then
      if ! grep -qF -- "\`$a\`" "$catalogue"; then
        emit "$dir" "flow:fixture-unknown-signature" CRITICAL "oracle signature $a not catalogued in $catalogue"
      fi
    fi
  done
done

exit 0
