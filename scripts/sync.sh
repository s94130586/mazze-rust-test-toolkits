#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
rsync -mravz $DIR/../../../ mazze:~/mazze-rust --prune-empty-dirs --include "*/" --include="*.rs" --include="*.py" --include="*.sh" --include="*.toml" --exclude="*"
#ssh mazze /home/ec2-user/mazze-rust/tests/scripts/sync_replicas.sh
