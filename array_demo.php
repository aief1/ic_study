<?php
// 数组方法演示
$arr = [3, 1, 4, 1, 5, 9, 2, 6];

echo "原始数组: " . implode(', ', $arr) . "\n\n";

// 翻转 reverse
$rev = array_reverse($arr);
echo "reverse (翻转): " . implode(', ', $rev) . "\n";

// 乱序 shuffle
$shuf = $arr;
shuffle($shuf);
echo "shuffle (乱序): " . implode(', ', $shuf) . "\n";

// 升序排列 sort
$sorted = $arr;
sort($sorted);
echo "sort (升序): " . implode(', ', $sorted) . "\n";

// 降序排列 rsort
$rsorted = $arr;
rsort($rsorted);
echo "rsort (降序): " . implode(', ', $rsorted) . "\n";
