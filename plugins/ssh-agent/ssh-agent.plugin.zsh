lockdir=/tmp/oh-my-zsh-ssh-agent.lock

while true; do
    if mkdir "$lockdir" 2>/dev/null
    then    # directory did not exist, but was created successfully
        trap 'rm -rf "$lockdir"' 0    # remove directory when script finishes
        break    # continue with script
    else
        sleep 0.1  # sleep for 0.2 and try again
    fi
done

typeset _agent_forwarding _ssh_env_cache

function _start_agent() {
	local lifetime
	local -a identities

	# start ssh-agent and setup environment
	zstyle -s :omz:plugins:ssh-agent lifetime lifetime

	ssh-agent -s ${lifetime:+-t} ${lifetime} | sed 's/^echo/#echo/' >! $_ssh_env_cache
	chmod 600 $_ssh_env_cache
	. $_ssh_env_cache > /dev/null

	# load identies
	zstyle -a :omz:plugins:ssh-agent identities identities

	echo starting ssh-agent...
	ssh-add $HOME/.ssh/${^identities}
}

# Get the filename to store/lookup the environment from
_ssh_env_cache="$HOME/.ssh/environment-$SHORT_HOST"

# test if agent-forwarding is enabled
zstyle -b :omz:plugins:ssh-agent agent-forwarding _agent_forwarding

if [[ $_agent_forwarding == "yes" && -n "$SSH_AUTH_SOCK" ]]; then
	# Add a nifty symlink for screen/tmux if agent forwarding
	[[ -L $SSH_AUTH_SOCK ]] || ln -sf "$SSH_AUTH_SOCK" /tmp/ssh-agent-$USER-screen
elif [[ -f "$_ssh_env_cache" ]]; then
	# Source SSH settings, if applicable
	. $_ssh_env_cache > /dev/null
	ps x | grep ssh-agent | grep -q $SSH_AGENT_PID || {
		_start_agent
	}
else
	_start_agent
fi

# tidy up after ourselves
unset _agent_forwarding _ssh_env_cache
unfunction _start_agent

rm -rf "$lockdir"
