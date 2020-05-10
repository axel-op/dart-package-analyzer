const core = require('@actions/core');
const exec = require('@actions/exec');

async function run() {
    try {
        const flutterHome = process.env.FLUTTER_HOME;
        const workspace = process.env.GITHUB_WORKSPACE;
        await core.addPath(`${flutterHome}/.pub-cache/bin`);
        await exec.exec('flutter', ['pub', 'global', 'activate', 'pana']);
        await exec.exec('flutter', ['run', `${workspace}/app/bin/main.dart`]);
    }
    catch (error) {
        core.setFailed(error.message);
    }
}

run()