function mk_prompt() {
    local exit_stat='%(1V.%F{red}%B%1v%b%f .)'
    local dir_info='%F{green}%~%f'
    local git_info='%(2V. %K{#008000}%F{#ffffff}%2v%f%k.)'
    local git_stat='%(3V.%K{#006400}%F{#ffffff}%3v%f%k.)'
    local k8s_info='%(4V. %K{#326ce5}%F{#ffffff}%4v%f%k.)'
    echo "%F{#999999}%T%f ${exit_stat}${dir_info}${git_info}${git_stat}${k8s_info}"
    echo -n '%# '
}

PROMPT="$(mk_prompt)"
setopt PROMPT_SP
setopt PROMPT_SUBST
unset RPS1

function precmd() {
    local exit_stat=$(format_exit $?)
    if gitstatus_query KK ; then
	if [[ $VCS_STATUS_RESULT == 'ok-sync' ]] ; then
	    local git_info=$(format_git_info)
	    local git_stat=$(format_git_stat)
	else
	    local git_info='' git_stat=''
	fi
    else
	local git_info='git status' git_stat='problem'
    fi
    local k8s_info=$(format_k8s)
    psvar=("$exit_stat" "$git_info" "$git_stat" "$k8s_info")
}

function format_exit() {
    local code=$1
    if (( code == 0 )) ; then
        :
    elif (( code == 126 )) ; then
	echo denied
    elif (( code == 127 )) ; then
	echo wrong
    elif (( code > 128 && code < 255 )) ; then
	local signal=$(( code - 128 ))
	kill -l $signal
    else
	echo $code
    fi
}

gitstatus_stop KK &&
gitstatus_start -s -1 -u -1 -c -1 -d -1 KK

function format_git_info() {
    emulate -L zsh
    local res=$VCS_STATUS_LOCAL_BRANCH
    [[ -z $res ]] && res=$VCS_STATUS_TAG
    [[ -z $res ]] && res=${VCS_STATUS_COMMIT[1,15]}…
    echo "$res"
}

function format_git_stat() {
    local res=
    (( VCS_STATUS_COMMITS_BEHIND )) && res+=" ⇣${VCS_STATUS_COMMITS_BEHIND}"
    (( VCS_STATUS_COMMITS_AHEAD && !VCS_STATUS_COMMITS_BEHIND )) && res+=' '
    (( VCS_STATUS_COMMITS_AHEAD )) && res+="⇡${VCS_STATUS_COMMITS_AHEAD}"
    (( VCS_STATUS_PUSH_COMMITS_BEHIND )) && res+=" ⇠${VCS_STATUS_PUSH_COMMITS_BEHIND}"
    (( VCS_STATUS_PUSH_COMMITS_AHEAD && !VCS_STATUS_PUSH_COMMITS_BEHIND )) && res+=' '
    (( VCS_STATUS_PUSH_COMMITS_AHEAD )) && res+="⇢${VCS_STATUS_PUSH_COMMITS_AHEAD}"
    [[ -n $VCS_STATUS_ACTION ]] && res+=" «${VCS_STATUS_ACTION}»"
    (( VCS_STATUS_NUM_CONFLICTED )) && res+=" ✘${VCS_STATUS_NUM_CONFLICTED}"
    (( VCS_STATUS_NUM_STAGED )) && res+=" +${VCS_STATUS_NUM_STAGED}"
    (( VCS_STATUS_NUM_UNSTAGED )) && res+=" ~${VCS_STATUS_NUM_UNSTAGED}"
    (( VCS_STATUS_NUM_UNTRACKED )) && res+=" ?${VCS_STATUS_NUM_UNTRACKED}"
    echo "$res"
}

function format_k8s() {
    if kubectl config current-context &> /dev/null ; then
        local cluster namespace
        read cluster namespace <<< $(kubectl config view --minify --output 'go-template={{with index .contexts 0 "context"}}{{.cluster}} {{or .namespace ""}}{{end}}')
	echo "${cluster%%.*}:${namespace:-default}"
    fi
}

