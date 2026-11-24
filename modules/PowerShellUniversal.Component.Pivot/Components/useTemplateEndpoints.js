import { useCallback, useEffect, useMemo, useState } from "react";
import { callEndpoint, mergeTemplates, readTemplates, templateKey } from "./prepare";

/*
 * The Views menu's templates (-Templates and a template store) and the endpoints that save, delete and
 * publish them (-OnSaveTemplate, -OnDeleteTemplate, -OnPublishTemplate).
 * latest: a ref to the current props; fileShown: whether a reader's file is shown.
 */
export function useTemplateEndpoints(props, latest, fileShown) {
    // ---- templates -------------------------------------------------------------------------------
    const templatesKey = JSON.stringify(props.templates ?? null);
    const serverTemplates = useMemo(() => readTemplates(JSON.parse(templatesKey)), [templatesKey]);
    const [saved, setSaved] = useState([]);
    const [deleted, setDeleted] = useState(() => new Set());
    useEffect(() => {
        // new templates from the server include what was saved and leave out what was deleted
        setSaved([]);
        setDeleted(new Set());
    }, [templatesKey]);
    const templates = useMemo(() => mergeTemplates(serverTemplates, saved, deleted), [serverTemplates, saved, deleted]);
    // while a file is shown, "My views" are the browser's views of that file: the reader's own views of
    // the app's data on the server stay out (they cannot be saved over or deleted from here)
    const shownTemplates = useMemo(() => (fileShown ? templates.filter((t) => t.scope !== "user") : templates), [fileShown, templates]);

    // a template the server confirmed: shown until the server sends the templates again
    const keep = useCallback((template) => {
        const key = templateKey(template.scope, template.name);
        setSaved((list) => [...list.filter((t) => templateKey(t.scope, t.name) !== key), template]);
        setDeleted((set) => {
            if (!set.has(key)) return set;
            const next = new Set(set);
            next.delete(key);
            return next;
        });
    }, []);
    // a file's views are kept by the browser's store (pivotkit keeps them per file), not by the server
    const serverSaves = !fileShown;
    const onSaveTemplate = serverSaves && typeof props.onSaveTemplate === "function"
        ? async (name, current) => {
              await callEndpoint(latest.current.onSaveTemplate, { name, view: current, json: JSON.stringify(current), scope: "user" });
              keep({ name, view: current, scope: "user", deletable: true });
          }
        : undefined;
    const onDeleteTemplate = serverSaves && typeof props.onDeleteTemplate === "function"
        ? async (name, how) => {
              const scope = how && how.scope === "shared" ? "shared" : "user";
              await callEndpoint(latest.current.onDeleteTemplate, { name, scope });
              setDeleted((set) => new Set(set).add(templateKey(scope, name)));
          }
        : undefined;
    // -AdminRole: the server sends canPublish only to readers with one of its roles, and checks again
    const onPublishTemplate = serverSaves && props.canPublish === true && typeof props.onPublishTemplate === "function"
        ? async (name, current) => {
              await callEndpoint(latest.current.onPublishTemplate, { name, view: current, json: JSON.stringify(current), scope: "shared" });
              keep({ name, view: current, scope: "shared", deletable: true });
          }
        : undefined;
    return { shownTemplates, onSaveTemplate, onDeleteTemplate, onPublishTemplate };
}
