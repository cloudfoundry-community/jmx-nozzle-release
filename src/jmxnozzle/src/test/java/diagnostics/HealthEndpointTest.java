package diagnostics;

import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import helpers.OutputLogRedirector;
import integration.FakeEgressImpl;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.HttpClientBuilder;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;

import static org.assertj.core.api.Java6Assertions.assertThat;

public class HealthEndpointTest {
    Process process;

    @BeforeEach
    public void setupTests() throws IOException {
        ProcessBuilder pb = new ProcessBuilder("java",
                "-jar", "./build/libs/jmx-nozzle-1.0-SNAPSHOT.jar"
        );
        process = pb.start();

        OutputLogRedirector outputLogRedirector = new OutputLogRedirector();
        outputLogRedirector.writeLogsToStdout(process);
    }

    @AfterEach
    public void shutdown() throws InterruptedException {
        process.destroy();
        process.waitFor();
    }

    @Test()
    @DisplayName("Health point receives metrics")
    public void getHealthInfo() throws Exception {
        FakeEgressImpl fakeLoggregator = new FakeEgressImpl();
        try {
            fakeLoggregator.start();

            Thread.sleep(1000);

            JsonObject response = getResponse("http://localhost:8080/health");
            assertThat(response.get("metrics_received").getAsInt()).isGreaterThan(0);
            assertThat(response.get("metrics_emitted").getAsInt()).isGreaterThan(0);
        } finally {
            fakeLoggregator.stop();
        }
    }

    public JsonObject getResponse(String url) throws IOException {
        HttpClient client = HttpClientBuilder.create().build();
        HttpGet request = new HttpGet(url);
        HttpResponse response = client.execute(request);
        assertThat(response.getStatusLine().getStatusCode()).isEqualTo(200);

        BufferedReader reader = new BufferedReader(new InputStreamReader(response.getEntity().getContent()));

        JsonParser jsonParser = new JsonParser();
        JsonElement element = jsonParser.parse(reader);

        return element.getAsJsonObject();
    }
}