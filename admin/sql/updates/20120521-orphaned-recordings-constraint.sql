BEGIN;

CREATE OR REPLACE FUNCTION delete_orphaned_recordings()
RETURNS TRIGGER
AS $$
  BEGIN
    PERFORM TRUE
    FROM recording outer_r
    WHERE id = OLD.recording
      AND edits_pending = 0
      AND NOT EXISTS (
        SELECT TRUE
        FROM edit JOIN edit_recording er ON edit.id = er.edit
        WHERE er.recording = outer_r.id
          AND type IN (71, 207, 218)
          LIMIT 1
      ) AND NOT EXISTS (
        SELECT TRUE FROM track WHERE track.recording = outer_r.id LIMIT 1
      ) AND NOT EXISTS (
        SELECT TRUE FROM l_artist_recording WHERE entity1 = outer_r.id
          UNION ALL
        SELECT TRUE FROM l_label_recording WHERE entity1 = outer_r.id
          UNION ALL
        SELECT TRUE FROM l_recording_recording WHERE entity1 = outer_r.id OR entity0 = outer_r.id
          UNION ALL
        SELECT TRUE FROM l_recording_release WHERE entity0 = outer_r.id
          UNION ALL
        SELECT TRUE FROM l_recording_release_group WHERE entity0 = outer_r.id
          UNION ALL
        SELECT TRUE FROM l_recording_work WHERE entity0 = outer_r.id
          UNION ALL
         SELECT TRUE FROM l_recording_url WHERE entity0 = outer_r.id
      );

    IF FOUND THEN
      -- Remove references from tables that don't change whether or not this recording
      -- is orphaned.
      DELETE FROM isrc WHERE recording = OLD.recording;
      DELETE FROM recording_annotation WHERE recording = OLD.recording;
      DELETE FROM recording_gid_redirect WHERE new_id = OLD.recording;
      DELETE FROM recording_puid WHERE recording = OLD.recording;
      DELETE FROM recording_rating_raw WHERE recording = OLD.recording;
      DELETE FROM recording_tag WHERE recording = OLD.recording;
      DELETE FROM recording_tag_raw WHERE recording = OLD.recording;

      DELETE FROM recording WHERE id = OLD.recording;
    END IF;
  END;
$$ LANGUAGE 'plpgsql';

CREATE CONSTRAINT TRIGGER remove_orphaned_tracks
AFTER DELETE OR UPDATE ON track DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE PROCEDURE delete_orphaned_recordings();

COMMIT;
