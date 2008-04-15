export PERL5LIB=$HOME/local/lib/perl5:$HOME/local/lib/perl5/site_perl/5.8
for t in tsts/*.pm;
do
  perl ~/local/lib/perl5/site_perl/5.8/Test/TestRunner.pl $t
done

