#!/bin/bash -ex
export LC_COLLATE=C
INPUT="$1"

if false; then
if [ ! -e "$INPUT" ]; then
    echo "Input does not exist!"
    exit 1  
fi

OUT="$(mktemp --tmpdir=/local)"

mawk 'BEGIN { FS="\t"; } { if(!($2 in types)) { types[$2]=1 } } END { for (type in types) print type }' $INPUT | sort -u > "$OUT"

psql <<HEREDOC
BEGIN;
CREATE TABLE IF NOT EXISTS id_types (
    id integer NOT NULL,
    name text
);

CREATE SEQUENCE IF NOT EXISTS id_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
    
ALTER SEQUENCE id_types_id_seq OWNED BY id_types.id;
ALTER TABLE ONLY id_types ALTER COLUMN id SET DEFAULT nextval('id_types_id_seq'::regclass);

ALTER TABLE ONLY id_types
    DROP CONSTRAINT IF EXISTS id_types_name_key CASCADE;

ALTER TABLE ONLY id_types
    DROP CONSTRAINT IF EXISTS id_types_pkey CASCADE;

CREATE TEMP TABLE tmp_id_types 
ON COMMIT DROP
AS
SELECT * 
FROM id_types
WITH NO DATA;

COPY tmp_id_types(name) FROM '$OUT' WITH ( DELIMITER E'\t', NULL 'NULL' );

INSERT INTO id_types(name)
(SELECT DISTINCT name FROM tmp_id_types WHERE name NOT IN (SELECT name FROM id_types));

ALTER TABLE ONLY id_types
    ADD CONSTRAINT id_types_name_key UNIQUE (name);

ALTER TABLE ONLY id_types
    ADD CONSTRAINT id_types_pkey PRIMARY KEY (id);
COMMIT;
HEREDOC

psql > $OUT <<COPYDOC
COPY (SELECT id, name FROM id_types) TO stdout DELIMITER E'\t';
COPYDOC

IMPORT="$(mktemp --tmpdir=/local)"

mawk -f- $INPUT > "$IMPORT" <<AWKDOC
BEGIN {
    FS="\\t";
    while ((getline line < "$OUT") > 0 ) {
        split(line, a, "\\t");
        types[a[2]] = a[1];
    }
}

{
    print \$1"\\t"types[\$2]"\\t"\$3;
}
AWKDOC

SORTED="$(mktemp --tmpdir=/local)"
LC_ALL=C sort -u -S100G --parallel=16 --temporary-directory=/local $IMPORT > $SORTED 
rm -f $IMPORT

mawk 'BEGIN { FS="\t"; } length($3) > 2 && length($3) <= 63 { print $0; }' "${SORTED}" > "${SORTED}_new"
mv -f "${SORTED}_new" "${SORTED}"

psql <<CLEANUPDOC
TRUNCATE id_mapping;

ALTER TABLE ONLY id_mapping
    DROP CONSTRAINT IF EXISTS id_mapping_pkey;

ALTER TABLE ONLY id_mapping
    DROP CONSTRAINT IF EXISTS id_mapping_type_fkey;

ALTER TABLE ONLY id_mapping
    DROP CONSTRAINT IF EXISTS id_mapping_id_text_pattern_ops_idx;

ALTER TABLE ONLY id_mapping
    DROP CONSTRAINT IF EXISTS id_mapping_id_lower_varchar_pattern_ops_idx; 

VACUUM FULL id_mapping;
CLEANUPDOC

psql <<SQLDOC
ALTER SYSTEM SET shared_buffers = '30GB';
ALTER SYSTEM SET maintenance_work_mem = '10GB';
ALTER SYSTEM SET work_mem = '10GB';

BEGIN;
CREATE TABLE IF NOT EXISTS id_mapping (
    "AC" varchar(32),
    type integer,
    "ID" varchar(64)
);
COPY id_mapping FROM '$SORTED' WITH ( DELIMITER E'\t', NULL 'NULL' );
END;

ALTER SYSTEM RESET shared_buffers;
ALTER SYSTEM RESET maintenance_work_mem;
ALTER SYSTEM RESET work_mem;
SQLDOC

fi
psql <<REBUILDINDEX
ALTER SYSTEM SET shared_buffers = '30GB';
ALTER SYSTEM SET maintenance_work_mem = '10GB';
ALTER SYSTEM SET work_mem = '10GB';

BEGIN;
-- ALTER TABLE ONLY id_mapping ADD CONSTRAINT id_mapping_pkey PRIMARY KEY ("AC", type, "ID");
ALTER TABLE ONLY id_mapping ADD CONSTRAINT id_mapping_type_fkey FOREIGN KEY (type) REFERENCES id_types(id);
DROP INDEX IF EXISTS id_mapping_id_lower_varchar_pattern_ops_idx;
CREATE INDEX id_mapping_id_lower_varchar_pattern_ops_idx ON id_mapping (lower("ID") varchar_pattern_ops);
END;

ALTER SYSTEM RESET shared_buffers;
ALTER SYSTEM RESET maintenance_work_mem;
ALTER SYSTEM RESET work_mem;
REBUILDINDEX
