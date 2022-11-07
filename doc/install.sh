# print scripts (default to ride)
[ -z "$1" ] && { bin_name="ride"; true; } || bin_name="$@"

echo "echo \"Installing $bin_name\""
echo 'echo $PATH'

echo sudo tee \""/usr/local/bin/$bin_name"\" '<<' \'EOF_RIDE\'

cat "/usr/local/bin/$bin_name.sh"

echo "EOF_RIDE"

echo "sudo chmod +x /usr/local/bin/$bin_name"

echo "mkdir -p ~/.ride/Share ~/.ride/chrome ~/.ride/firefox ~/.ride/remmina"
