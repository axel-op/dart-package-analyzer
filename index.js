const core = require('@actions/core');
const exec = require('@actions/exec');

async function run() {
    try {
        const home = process.env.HOME;
        const workspace = process.env.GITHUB_WORKSPACE;
        await core.addPath(`${home}/flutter/bin`);
        await core.addPath(`${home}/flutter/bin/cache/dart-sdk/bin`);
        await core.addPath(`${home}/.pub-cache/bin`);
        await exec.exec('flutter', ['pub', 'global', 'activate', 'pana']);
        await exec.exec('flutter', ['run', `${workspace}/app/bin/main.dart`]);
    }
    catch (error) {
        core.setFailed(error.message);
    }
}

run()