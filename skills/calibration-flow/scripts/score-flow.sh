#!/usr/bin/env bash
# score-flow.sh — pure, deterministic scorer for behavioural-flow evaluation.
# Diffs recorded actual findings against an expected.md oracle. No LLM, no network, no writes.
# Usage: score-flow.sh --expected <expected.md> --actual <actual.tsv> [--actual-flow <f.tsv>] [--format report|tsv]
#   --actual      TSV: node<TAB>signature<TAB>severity<TAB>detail   (optional header row tolerated)
#   --actual-flow TSV: ac<TAB>status<TAB>blocker                    (optional)
# Exit codes (load-bearing): 0 scored→pass · 1 scored→fail · 2 could-not-score (broken/missing input).
set -euo pipefail

expected=""; actual=""; actualflow=""; format="report"
while [ $# -gt 0 ]; do
  case "$1" in
    --expected)    expected="${2:-}"; shift 2 ;;
    --actual)      actual="${2:-}"; shift 2 ;;
    --actual-flow) actualflow="${2:-}"; shift 2 ;;
    --format)      format="${2:-report}"; shift 2 ;;
    -h|--help)     sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "score-flow: unknown arg: $1" >&2; exit 2 ;;
  esac
done

# can't-score guards (exit 2 is reserved for "the engine could not run", never a clean fail)
[ -n "$expected" ] && [ -f "$expected" ] || { echo "score-flow: missing --expected file" >&2; exit 2; }
[ -n "$actual" ]   && [ -f "$actual" ]   || { echo "score-flow: missing --actual file" >&2; exit 2; }
grep -qE '^case:' "$expected" || { echo "score-flow: $expected has no 'case:' frontmatter" >&2; exit 2; }
case "$format" in report|tsv) : ;; *) echo "score-flow: --format must be report|tsv" >&2; exit 2 ;; esac

af="${actualflow:-/dev/null}"

set +e
awk -v EXP="$expected" -v ACT="$actual" -v AF="$af" -v FORMAT="$format" '
function trim(s){ gsub(/^[[:space:]]+|[[:space:]]+$/,"",s); return s }
function sevn(s){ if(s=="CRITICAL")return 5; if(s=="HIGH")return 4; if(s=="MEDIUM")return 3; if(s=="LOW")return 2; if(s=="INFO")return 1; return 0 }
function reg(node){ if(!(node in nodeidx)){ nodeidx[node]=++nn; nodeorder[nn]=node } }

BEGIN{ fm=0; sec=""; fence=0; hdr=0; np=0; ne=0; ni=0; na=0; nn=0 }

# ---- expected.md: frontmatter + three fenced TSV tables -------------------------------------------
FILENAME==EXP {
  if($0 ~ /^---[[:space:]]*$/){ fm++; next }
  if(fm==1){
    if($0 ~ /^case:/)  ocase=trim(substr($0,index($0,":")+1))
    if($0 ~ /^class:/) oclass=trim(substr($0,index($0,":")+1))
    next
  }
  if($0 ~ /^##[[:space:]]+Planted defects/){ sec="planted"; fence=0; hdr=0; next }
  if($0 ~ /^##[[:space:]]+Edge contracts/){ sec="edge"; fence=0; hdr=0; next }
  if($0 ~ /^##[[:space:]]+Intent acceptance criteria/){ sec="intent"; fence=0; hdr=0; next }
  if($0 ~ /^##[[:space:]]/){ sec=""; fence=0; next }
  if(sec!="" && $0 ~ /^[[:space:]]*```/){ fence=(fence==0)?1:0; hdr=0; next }
  if(sec!="" && fence==1){
    if($0 ~ /^[[:space:]]*$/) next
    if(hdr==0){ hdr=1; next }                 # skip the column-header row
    n=split($0,c,"\t"); for(x=1;x<=n;x++) c[x]=trim(c[x])
    if(sec=="planted"){
      np++; p_node[np]=c[2]; p_sig[np]=c[3]; p_sev[np]=c[4]; p_must[np]=c[5]
      reg(c[2]); sig_node[c[3]]=c[2]
    } else if(sec=="edge"){
      ne++; e_seam[ne]=c[1]; e_sig[ne]=c[2]; e_must[ne]=c[3]
    } else if(sec=="intent"){
      ni++; i_ac[ni]=c[1]; i_exp[ni]=c[2]; i_owner[ni]=c[3]
    }
    next
  }
  next
}

# ---- actual.tsv: recorded findings ----------------------------------------------------------------
FILENAME==ACT {
  if($0 ~ /^[[:space:]]*$/) next
  n=split($0,c,"\t"); for(x=1;x<=n;x++) c[x]=trim(c[x])
  if(FNR==1 && c[1]=="node") next            # tolerate an optional header row
  na++; a_node[na]=c[1]; a_sig[na]=c[2]; a_sev[na]=c[3]
  reg(c[1]); asig_set[c[2]]=1
  next
}

# ---- actual-flow.tsv: recorded AC outcomes --------------------------------------------------------
FILENAME==AF {
  if($0 ~ /^[[:space:]]*$/) next
  n=split($0,c,"\t"); for(x=1;x<=n;x++) c[x]=trim(c[x])
  if(FNR==1 && c[1]=="ac") next
  af_status[c[1]]=c[2]
  next
}

END{
  # caught[]: a must_catch planted defect is caught when an actual row shares (node,signature)
  #           AND records severity >= the oracle severity (under-grading does not count).
  for(i=1;i<=np;i++){
    caught[i]=0
    if(p_must[i]=="yes")
      for(j=1;j<=na;j++)
        if(a_node[j]==p_node[i] && a_sig[j]==p_sig[i] && sevn(a_sev[j])>=sevn(p_sev[i])){ caught[i]=1; break }
  }
  # a_true[]: an actual row is a true finding when it matches some planted (node,signature).
  for(j=1;j<=na;j++){
    a_true[j]=0
    for(i=1;i<=np;i++) if(p_node[i]==a_node[j] && p_sig[i]==a_sig[j]){ a_true[j]=1; break }
  }

  totalM=0; totalC=0; highmiss=0

  # ---- node level ----
  for(k=1;k<=nn;k++){
    node=nodeorder[k]; M=0; C=0; A=0; T=0; crossnode=0
    for(i=1;i<=np;i++) if(p_node[i]==node && p_must[i]=="yes"){ M++; if(caught[i]) C++ }
    for(j=1;j<=na;j++) if(a_node[j]==node){
      A++; if(a_true[j]) T++
      if((a_sig[j] in sig_node) && sig_node[a_sig[j]]!=node) crossnode=1
    }
    totalM+=M; totalC+=C
    n_M[k]=M; n_C[k]=C; n_A[k]=A; n_T[k]=T; n_cross[k]=crossnode
  }
  for(i=1;i<=np;i++) if(p_must[i]=="yes" && !caught[i] && sevn(p_sev[i])>=4) highmiss=1
  recall_ok = (totalM==0) ? 1 : (totalC==totalM)

  # ---- edge level ----
  anyEdgeViolated=0
  for(i=1;i<=ne;i++){
    e_viol[i] = (e_must[i]=="yes" && (e_sig[i] in asig_set)) ? 1 : 0
    if(e_viol[i]) anyEdgeViolated=1
  }

  # ---- flow level ----
  anyMismatch=0; anyBlockedWaved=0; anyCoverageGap=0
  for(i=1;i<=ni;i++){
    st = (i_ac[i] in af_status) ? af_status[i_ac[i]] : "unknown"
    f_status[i]=st
    f_match[i] = (st==i_exp[i]) ? "match" : "mismatch"
    if(f_match[i]=="mismatch") anyMismatch=1
    if(i_exp[i]=="blocked" && st=="met") anyBlockedWaved=1
    if(i_owner[i]=="UNOWNED") anyCoverageGap=1
  }

  hard_fail = (highmiss || anyEdgeViolated || anyBlockedWaved) ? 1 : 0
  verdict = hard_fail ? "fail" : "pass"
  if(hard_fail) intent="low"
  else if(recall_ok && !anyMismatch && !anyCoverageGap && !anyEdgeViolated) intent="high"
  else intent="mid"

  if(FORMAT=="tsv"){
    for(k=1;k<=nn;k++)
      printf "node\t%s\trecall\t%s\tprecision\t%s\tscope\t%s\n",
        nodeorder[k], frac(n_C[k],n_M[k]), frac(n_T[k],n_A[k]), (n_cross[k]?"cross-node":"ok")
    for(i=1;i<=ne;i++) printf "edge\t%s\t%s\n", e_seam[i], (e_viol[i]?"violated":"met")
    for(i=1;i<=ni;i++) printf "flow\t%s\t%s\t%s\n", i_ac[i], f_status[i], f_match[i]
    printf "verdict\t%s\n", verdict
    printf "intent\t%s\n", intent
  } else {
    printf "# Behavioural-flow score — case %s (%s)\n\n", ocase, oclass
    print "## Node"
    for(k=1;k<=nn;k++)
      printf "- %s: recall %s, precision %s, scope %s\n",
        nodeorder[k], frac(n_C[k],n_M[k]), frac(n_T[k],n_A[k]), (n_cross[k]?"cross-node":"ok")
    miss=0
    for(i=1;i<=np;i++) if(p_must[i]=="yes" && !caught[i]){ if(!miss){print "\nMissed (must-catch):"; miss=1}
      printf "- %s %s/%s %s\n", p_sev[i], p_node[i], p_sig[i], "" }
    print "\n## Edge"
    if(ne==0) print "- (no edge contracts)"
    for(i=1;i<=ne;i++) printf "- %s: %s (%s)\n", e_seam[i], (e_viol[i]?"violated":"met"), e_sig[i]
    print "\n## Flow"
    if(ni==0) print "- (no acceptance criteria)"
    for(i=1;i<=ni;i++) printf "- %s: %s vs expected %s (%s)\n", i_ac[i], f_status[i], i_exp[i], f_match[i]
    printf "\n**Intent service score:** %s — %s\n", intent, rationale(intent, highmiss, anyEdgeViolated, anyBlockedWaved, anyCoverageGap, anyMismatch)
    printf "**Verdict:** %s\n", verdict
  }
  exit hard_fail
}
function frac(num,den){ return (den==0) ? "n/a" : (num "/" den) }
function rationale(s,hm,ev,bw,cg,mm){
  if(s=="high") return "all must-catch defects caught, handoffs held, intent delivered"
  if(s=="low"){
    if(hm) return "a must-catch CRITICAL/HIGH defect was missed"
    if(ev) return "a must-hold handoff contract was violated"
    if(bw) return "an acceptance criterion expected blocked was waved through as met"
    return "hard failure"
  }
  if(cg) return "a needed concern has no owning node (coverage gap)"
  if(mm) return "an acceptance criterion did not match its expected status"
  return "partial delivery"
}
' "$expected" "$actual" "$af"
rc=$?
set -e
exit "$rc"
