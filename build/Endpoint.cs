// PSU's Endpoint type, for code that runs outside PSU: the Pester tests and the docs site build.
// A module turns an event script block into an Endpoint and registers it; Register records the id.
public class Endpoint {
    public System.Management.Automation.ScriptBlock ScriptBlock;
    public string RegisteredId;
    public Endpoint(System.Management.Automation.ScriptBlock scriptBlock) { ScriptBlock = scriptBlock; }
    public void Register(string id, object cmdlet) { RegisteredId = id; }
}
