# Java Web Demo (Calculator)

Tiny Java web application (WAR) demonstrating a servlet-based calculator.

Location: `c:\Gandhar\work\lecture\java-web-demo`

## Prerequisites
- Java 11+ installed and `java` on PATH
- Apache Maven installed and `mvn` on PATH
- Tomcat (9.x or 10.x) installed. Set `TOMCAT_HOME` environment variable or provide the path to `deploy.ps1`.

## Installing Java (helper script)

A helper PowerShell script is provided to download and install an OpenJDK build (Temurin) for Windows and set `JAVA_HOME` and update your user `PATH`.

From project root:




```
Get-ExecutionPolicy

Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted -Force

./install-java.ps1 -Version 17 -SetAsDefault
```

- `-Version` accepts 8, 11, 17, 21. Default is 17.
- `-SetAsDefault` writes `JAVA_HOME` and updates your user PATH using `setx`. You will need to open a new shell for changes to take effect.

If you don't want to modify environment variables, run the script without `-SetAsDefault` and it will print a command you can run in your current session to use the new JRE.

Note: The script uses Adoptium (Temurin) API endpoints to download the binaries. If the download fails due to network or API changes, please install Java manually from https://adoptium.net/ or https://jdk.java.net/ and set `JAVA_HOME` accordingly.

## Build
From project root run (PowerShell):

```
./build.ps1          # runs mvn clean package
# or to skip tests:
./build.ps1 -SkipTests
```

The WAR will be produced in `target\java-web-demo-1.0-SNAPSHOT.war` (name may vary by version).

## Deploy to Tomcat
Use the provided `deploy.ps1` script. It will copy the WAR to `TOMCAT_HOME\webapps`.

```
# If TOMCAT_HOME is set in environment:
./deploy.ps1

# Or pass the Tomcat path explicitly and restart Tomcat after deploy:
./deploy.ps1 -TomcatHome "C:\\path\\to\\apache-tomcat-9.0.xx" -RestartTomcat
```

After deployment, open: `http://localhost:8080/java-web-demo/` (WAR base name may change depending on artifactId/version).

## How to use the demo
- Open the index page and use the small form to compute simple expressions.
- Or call the servlet directly, e.g.: `/java-web-demo/calc?a=5&op=add&b=3`

## Notes
- `javax.servlet-api` is declared as `provided` in the POM; Tomcat provides the servlet API at runtime.
- If Tomcat auto-deploy is disabled, you may need to restart Tomcat for it to pick up the new WAR.

Enjoy!