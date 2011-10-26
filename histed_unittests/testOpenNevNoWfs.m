function testOpenNevNoWfs

ds = directories;

ns = openNEV(ds.nev1, 'read', 'nomat', 'nosave', 'nowfs');

assertTrue(isempty(ns.Data.Spikes.Waveform));
assertTrue(length(ns.Data.Spikes.TimeStamp) == 42237);
