const core = require('@actions/core');
const exec = require('@actions/exec');

async function run() {
    try {
        const flutterHome = process.env.FLUTTER_HOME;
        const workspace = process.env.GITHUB_WORKSPACE;
        core.addPath(`${flutterHome}/.pub-cache/bin`);
        await exec.exec('pub', ['global', 'activate', 'pana']);
        const options = { cwd: `${workspace}/app` };
        await exec.exec('pub', ['get'], options)
        await exec.exec('dart', ['bin/main.dart'], options);
    }
    catch (error) {
        core.setFailed(error.message);
    }
}

run()